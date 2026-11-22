use std::io::Write;
use std::path::PathBuf;

use tempfile::TempDir;
use thiserror::Error;

use crate::build::{self, BuildError};
use crate::config::Config;
use crate::diff::PackageChange;
use crate::format::format_notification_bodies;
use crate::lock::{self, LockError};
use crate::notify::{self, NotificationPayload, Notifier, NotifyError};
use crate::pending::{self, Pending};

#[derive(Debug, Error)]
pub enum RunError {
    #[error("{0}")]
    Lock(#[from] LockError),
    #[error("{0}")]
    Build(#[from] BuildError),
    #[error("{0}")]
    Notify(#[from] NotifyError),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CheckOutcome {
    /// Flake lock already current — nothing to report.
    UpToDate,
    /// A lock-bump PR is already open, so the local upstream check (and its build) is
    /// skipped: the PR body carries the per-host diff.
    ReviewPending,
    /// Lock would change but package diff was skipped (`lock_only` or low memory).
    LockUpdatesPending {
        reason: String,
        payloads: Vec<NotificationPayload>,
    },
    /// Built new closure and listed exact package changes.
    PackageUpdates {
        changes: Vec<PackageChange>,
        payloads: Vec<NotificationPayload>,
    },
    /// Lock changed but closures are identical at package level.
    LockChangedNoPackageDiff,
}

/// Everything one run found: operator actions pending, and what upstream would change.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CheckReport {
    pub pending: Pending,
    pub outcome: CheckOutcome,
}

/// Where a lock bump should come from, appended to every "upstream moved" notice.
const BUMP_HINT: &str = "Lock bumps land as a reviewed PR: run the \"Update flake.lock\" \
workflow, or bump on a branch with bin/update/flake. Hosts converge from merged main.";

pub fn run_check(config: &Config, notifier: &mut dyn Notifier) -> Result<CheckReport, RunError> {
    let pending = collect_pending(config);
    maybe_notify(config, notifier, &pending::pending_payloads(&pending))?;

    let outcome = if pending.lock_prs.is_empty() {
        check_upstream(config, notifier)?
    } else {
        CheckOutcome::ReviewPending
    };
    Ok(CheckReport { pending, outcome })
}

fn collect_pending(config: &Config) -> Pending {
    let lock_prs = if config.github_repo.is_empty() {
        Vec::new()
    } else {
        pending::open_lock_prs(&config.github_repo, &config.lock_branch)
    };
    Pending {
        reboot: pending::reboot_differences(&config.booted_system, &config.current_system),
        lock_prs,
    }
}

/// Would `nix flake update` move the lock, and if so, what would change for this host.
fn check_upstream(config: &Config, notifier: &mut dyn Notifier) -> Result<CheckOutcome, RunError> {
    let work = TempDir::new()?;
    let new_lock = work.path().join("flake.lock");
    lock::update_lock_to(config.flake_dir(), &new_lock)?;

    if !lock::lock_changed(config.flake_dir(), &new_lock)? {
        return Ok(CheckOutcome::UpToDate);
    }

    if let Some(reason) = skip_build_reason(config)? {
        let payloads = vec![NotificationPayload {
            summary: "NixOS flake updates available".into(),
            body: format!("{}\n{BUMP_HINT}", reason.1),
        }];
        maybe_notify(config, notifier, &payloads)?;
        return Ok(CheckOutcome::LockUpdatesPending {
            reason: reason.0,
            payloads,
        });
    }

    let out_link = work.path().join("result");
    let new_system =
        build::build_toplevel(config.flake_dir(), &config.hostname, &new_lock, &out_link)?;

    let changes = build::diff_closures(
        config.differ,
        &config.vdiff,
        &config.current_system,
        &new_system,
    )?;
    if changes.is_empty() {
        return Ok(CheckOutcome::LockChangedNoPackageDiff);
    }

    let bodies = format_notification_bodies(&changes, config.body_limit);
    let payloads = notify::payloads_for_updates(changes.len(), &bodies);
    maybe_notify(config, notifier, &payloads)?;

    Ok(CheckOutcome::PackageUpdates { changes, payloads })
}

/// `(reason, notification text)` when the closure build must be skipped.
fn skip_build_reason(config: &Config) -> Result<Option<(String, String)>, RunError> {
    if config.lock_only {
        return Ok(Some((
            "lock_only".into(),
            "flake.lock would change. Re-run without --lock-only to list packages.".into(),
        )));
    }
    let avail = build::available_memory_mib()?;
    if avail < config.min_mem_mib {
        return Ok(Some((
            format!("low_memory:{avail}"),
            format!(
                "flake.lock would change, but only {avail} MiB RAM is free \
(need ≥ {} MiB to build and list packages). Free memory, then run:\n  nixos-update-notifier",
                config.min_mem_mib
            ),
        )));
    }
    Ok(None)
}

fn maybe_notify(
    config: &Config,
    notifier: &mut dyn Notifier,
    payloads: &[NotificationPayload],
) -> Result<(), NotifyError> {
    if config.no_notify {
        return Ok(());
    }
    deliver(notifier, payloads, &mut std::io::stderr())
}

/// Send each notice. A host with no notification server (GH-277: mimir, headless) gets
/// the notice in the journal instead, and the run goes on; any other send error stops it.
fn deliver(
    notifier: &mut dyn Notifier,
    payloads: &[NotificationPayload],
    log: &mut dyn Write,
) -> Result<(), NotifyError> {
    for p in payloads {
        match notifier.notify(p) {
            Err(NotifyError::NoServer(detail)) => {
                // A notice that cannot reach stderr either has nowhere left to go.
                let _ = writeln!(
                    log,
                    "nixos-update-notifier: no notification server reachable ({detail}); \
logging the notice instead\n--- {} ---\n{}",
                    p.summary, p.body
                );
            }
            other => other?,
        }
    }
    Ok(())
}

/// The unified root flake (ADR-0001): every host is `nixosConfigurations.<host>` of
/// `$HOME/.dotfiles`; there are no per-host flakes to point at.
pub fn default_flake_dir(home: &str) -> PathBuf {
    PathBuf::from(home).join(".dotfiles")
}

#[cfg(test)]
mod tests {
    use super::*;
    use clap::Parser;
    use std::fs;
    use std::os::unix::fs::symlink;
    use tempfile::tempdir;

    #[derive(Default)]
    struct Recorder(Vec<NotificationPayload>);

    impl Notifier for Recorder {
        fn notify(&mut self, payload: &NotificationPayload) -> Result<(), NotifyError> {
            self.0.push(payload.clone());
            Ok(())
        }
    }

    /// A headless host: nothing answers on org.freedesktop.Notifications.
    #[derive(Default)]
    struct Headless(usize);

    impl Notifier for Headless {
        fn notify(&mut self, _: &NotificationPayload) -> Result<(), NotifyError> {
            self.0 += 1;
            Err(NotifyError::NoServer(
                "org.freedesktop.DBus.Error.ServiceUnknown: no Notifications owner".into(),
            ))
        }
    }

    /// A notification server that is there but refuses.
    struct Broken;

    impl Notifier for Broken {
        fn notify(&mut self, _: &NotificationPayload) -> Result<(), NotifyError> {
            Err(NotifyError::Send(
                "org.freedesktop.DBus.Error.AccessDenied".into(),
            ))
        }
    }

    /// A config whose reboot check finds a pending kernel and whose upstream check then
    /// fails on the missing flake directory.
    fn reboot_pending_config(t: &std::path::Path) -> Config {
        let (old, new) = (t.join("linux-old"), t.join("linux-new"));
        fs::write(&old, "o").unwrap();
        fs::write(&new, "n").unwrap();
        for (name, kernel) in [("booted", &old), ("current", &new)] {
            fs::create_dir(t.join(name)).unwrap();
            symlink(kernel, t.join(name).join("kernel")).unwrap();
        }
        Config::parse_from([
            "nixos-update-notifier",
            "--flake",
            t.join("no-flake").to_str().unwrap(),
            "--booted-system",
            t.join("booted").to_str().unwrap(),
            "--current-system",
            t.join("current").to_str().unwrap(),
        ])
    }

    // GH-277: no notification server is not a failure; every notice is logged instead.
    #[test]
    fn no_server_logs_every_notice_and_succeeds() {
        let payloads = notify::payloads_for_updates(3, &["a: 1 → 2".into(), "b: 3 → 4".into()]);
        let mut headless = Headless::default();
        let mut log = Vec::new();
        deliver(&mut headless, &payloads, &mut log).unwrap();
        assert_eq!(headless.0, 2);
        let log = String::from_utf8(log).unwrap();
        assert_eq!(log.matches("no notification server reachable").count(), 2);
        assert!(log.contains("NixOS updates available (3 packages, 1/2)"));
        assert!(log.contains("b: 3 → 4"));
    }

    // ...so the run goes past the notice: what stops it (exit 1) is the real error after.
    #[test]
    fn no_server_does_not_stop_the_run() {
        let t = tempdir().unwrap();
        let config = reboot_pending_config(t.path());
        let mut headless = Headless::default();
        let err = run_check(&config, &mut headless).unwrap_err();
        assert!(matches!(err, RunError::Lock(LockError::MissingFlakeDir(_))));
        assert_eq!(headless.0, 1);
    }

    #[test]
    fn other_send_errors_still_fail_the_run() {
        let t = tempdir().unwrap();
        let config = reboot_pending_config(t.path());
        let err = run_check(&config, &mut Broken).unwrap_err();
        assert!(matches!(err, RunError::Notify(NotifyError::Send(_))));
    }

    #[test]
    fn default_flake_dir_is_the_root_flake() {
        let p = default_flake_dir("/home/tom");
        assert_eq!(p, PathBuf::from("/home/tom/.dotfiles"));
    }

    #[test]
    fn lock_only_skips_the_build_and_points_at_the_pr_flow() {
        let config = Config::parse_from(["nixos-update-notifier", "--lock-only"]);
        let (reason, _) = skip_build_reason(&config).unwrap().unwrap();
        assert_eq!(reason, "lock_only");
        assert!(BUMP_HINT.contains("Update flake.lock"));
    }

    // A reboot notice goes out before the upstream check runs, so it reaches the
    // operator even when that check then fails (here: no flake directory).
    #[test]
    fn reboot_pending_is_notified_before_the_upstream_check() {
        let t = tempdir().unwrap();
        let config = reboot_pending_config(t.path());
        let mut rec = Recorder::default();
        let err = run_check(&config, &mut rec).unwrap_err();
        assert!(matches!(err, RunError::Lock(LockError::MissingFlakeDir(_))));
        assert_eq!(rec.0.len(), 1);
        assert_eq!(rec.0[0].summary, "NixOS reboot pending");
    }

    #[test]
    fn no_notify_suppresses_pending_notices() {
        let t = tempdir().unwrap();
        let k = t.path().join("k");
        fs::write(&k, "k").unwrap();
        fs::create_dir(t.path().join("current")).unwrap();
        symlink(&k, t.path().join("current").join("kernel")).unwrap();
        let config = Config::parse_from([
            "nixos-update-notifier",
            "--no-notify",
            "--flake",
            t.path().join("no-flake").to_str().unwrap(),
            "--booted-system",
            t.path().join("absent").to_str().unwrap(),
            "--current-system",
            t.path().join("current").to_str().unwrap(),
        ]);
        let mut rec = Recorder::default();
        assert!(run_check(&config, &mut rec).is_err());
        assert!(rec.0.is_empty());
    }
}
