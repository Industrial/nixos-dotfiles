use std::path::PathBuf;

use tempfile::TempDir;
use thiserror::Error;

use crate::build::{self, BuildError};
use crate::config::Config;
use crate::diff::PackageChange;
use crate::format::format_notification_bodies;
use crate::lock::{self, LockError};
use crate::notify::{self, NotificationPayload, Notifier, NotifyError};

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

pub fn run_check(config: &Config, notifier: &mut dyn Notifier) -> Result<CheckOutcome, RunError> {
    let work = TempDir::new()?;
    let new_lock = work.path().join("flake.lock");
    lock::update_lock_to(&config.flake, &new_lock)?;

    if !lock::lock_changed(&config.flake, &new_lock)? {
        return Ok(CheckOutcome::UpToDate);
    }

    if config.lock_only {
        let payloads = vec![NotificationPayload {
            summary: "NixOS flake updates available".into(),
            body: "flake.lock would change. Re-run without --lock-only to list packages.".into(),
        }];
        maybe_notify(config, notifier, &payloads)?;
        return Ok(CheckOutcome::LockUpdatesPending {
            reason: "lock_only".into(),
            payloads,
        });
    }

    let avail = build::available_memory_mib()?;
    if avail < config.min_mem_mib {
        let payloads = vec![NotificationPayload {
            summary: "NixOS flake updates available".into(),
            body: format!(
                "flake.lock would change, but only {avail} MiB RAM is free \
(need ≥ {} MiB to build and list packages). Free memory, then run:\n  nixos-update-notifier",
                config.min_mem_mib
            ),
        }];
        maybe_notify(config, notifier, &payloads)?;
        return Ok(CheckOutcome::LockUpdatesPending {
            reason: format!("low_memory:{avail}"),
            payloads,
        });
    }

    let out_link = work.path().join("result");
    let new_system = build::build_toplevel(&config.flake, &config.hostname, &new_lock, &out_link)?;

    let changes = build::diff_closures(&config.current_system, &new_system)?;
    if changes.is_empty() {
        return Ok(CheckOutcome::LockChangedNoPackageDiff);
    }

    let bodies = format_notification_bodies(&changes, config.body_limit);
    let payloads = notify::payloads_for_updates(changes.len(), &bodies);
    maybe_notify(config, notifier, &payloads)?;

    Ok(CheckOutcome::PackageUpdates { changes, payloads })
}

fn maybe_notify(
    config: &Config,
    notifier: &mut dyn Notifier,
    payloads: &[NotificationPayload],
) -> Result<(), NotifyError> {
    if config.no_notify {
        return Ok(());
    }
    for p in payloads {
        notifier.notify(p)?;
    }
    Ok(())
}

/// Resolve defaults when CLI env vars are unset (hostname from kernel).
pub fn default_flake_dir(userdir: &str, hostname: &str) -> PathBuf {
    PathBuf::from(userdir)
        .join(".dotfiles")
        .join("hosts")
        .join(hostname)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_flake_dir_joins_host() {
        let p = default_flake_dir("/home/tom", "drakkar");
        assert_eq!(p, PathBuf::from("/home/tom/.dotfiles/hosts/drakkar"));
    }
}
