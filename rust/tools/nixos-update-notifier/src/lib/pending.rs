//! What is waiting on the operator, beyond "upstream moved".
//!
//! Under the update policy (docs/adr/0006-update-policy.md) a lock bump arrives as a
//! pull request, comin converges hosts from merged main, and nothing reboots on its own.
//! So the two things only the operator can do are: review the open lock-bump PR, and
//! reboot into a kernel that comin already switched to. This module detects both.

use std::fs;
use std::path::Path;
use std::process::Command;

use regex::Regex;

use crate::notify::NotificationPayload;

/// The links whose change `switch-to-configuration switch` cannot apply live. Same set
/// NixOS itself compares when deciding a reboot is needed.
const BOOT_LINKS: [&str; 3] = ["kernel", "initrd", "kernel-modules"];

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Pending {
    /// Which of [`BOOT_LINKS`] differ between the booted and the current system.
    pub reboot: Vec<String>,
    /// URLs of open lock-bump pull requests.
    pub lock_prs: Vec<String>,
}

impl Pending {
    pub fn is_empty(&self) -> bool {
        self.reboot.is_empty() && self.lock_prs.is_empty()
    }
}

/// Boot-critical links that differ between `booted` and `current`. A link missing on
/// both sides is not a difference; missing on one side is.
pub fn reboot_differences(booted: &Path, current: &Path) -> Vec<String> {
    BOOT_LINKS
        .iter()
        .filter(|name| {
            let b = fs::canonicalize(booted.join(name)).ok();
            let c = fs::canonicalize(current.join(name)).ok();
            b != c
        })
        .map(|name| (*name).to_string())
        .collect()
}

/// Pull request URLs out of a GitHub `GET /repos/{repo}/pulls` JSON response. Only
/// top-level PR URLs (`.../pull/<n>`) match; nested `html_url`s of users and repos do not.
pub fn parse_pull_urls(json: &str) -> Vec<String> {
    let re = Regex::new(r#""html_url"\s*:\s*"(https://github\.com/[^"/]+/[^"/]+/pull/\d+)""#)
        .expect("static regex");
    let mut urls: Vec<String> = re.captures_iter(json).map(|c| c[1].to_string()).collect();
    urls.dedup();
    urls
}

/// Open PRs from `branch` on public `repo` (`owner/name`), via the unauthenticated GitHub
/// API. Any failure (offline, rate limit, curl missing) yields an empty list: this is a
/// courtesy notice, never a reason for the timer unit to fail.
pub fn open_lock_prs(repo: &str, branch: &str) -> Vec<String> {
    let Some((owner, _)) = repo.split_once('/') else {
        return Vec::new();
    };
    let url = format!("https://api.github.com/repos/{repo}/pulls?state=open&head={owner}:{branch}");
    let out = Command::new("curl")
        .args([
            "-fsS",
            "--max-time",
            "20",
            "-H",
            "Accept: application/vnd.github+json",
        ])
        .arg(&url)
        .output();
    match out {
        Ok(o) if o.status.success() => parse_pull_urls(&String::from_utf8_lossy(&o.stdout)),
        _ => Vec::new(),
    }
}

/// One notification per kind of pending action.
pub fn pending_payloads(p: &Pending) -> Vec<NotificationPayload> {
    let mut out = Vec::new();
    if !p.lock_prs.is_empty() {
        out.push(NotificationPayload {
            summary: "NixOS lock bump awaiting review".into(),
            body: format!(
                "Review and merge to update the fleet (comin applies merged main):\n{}",
                p.lock_prs.join("\n")
            ),
        });
    }
    if !p.reboot.is_empty() {
        out.push(NotificationPayload {
            summary: "NixOS reboot pending".into(),
            body: format!(
                "The running system differs from the booted one in: {}.\n\
Reboot when convenient to boot the new {}.",
                p.reboot.join(", "),
                if p.reboot.iter().any(|r| r == "kernel") {
                    "kernel"
                } else {
                    "boot files"
                }
            ),
        });
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::symlink;
    use tempfile::tempdir;

    fn system(root: &Path, name: &str, kernel: &Path, initrd: &Path) -> std::path::PathBuf {
        let dir = root.join(name);
        fs::create_dir(&dir).unwrap();
        symlink(kernel, dir.join("kernel")).unwrap();
        symlink(initrd, dir.join("initrd")).unwrap();
        dir
    }

    fn file(root: &Path, name: &str) -> std::path::PathBuf {
        let p = root.join(name);
        fs::write(&p, name).unwrap();
        p
    }

    #[test]
    fn same_boot_links_need_no_reboot() {
        let t = tempdir().unwrap();
        let k = file(t.path(), "linux-6.18.59");
        let i = file(t.path(), "initrd-a");
        let booted = system(t.path(), "booted", &k, &i);
        let current = system(t.path(), "current", &k, &i);
        assert!(reboot_differences(&booted, &current).is_empty());
    }

    #[test]
    fn kernel_move_needs_reboot() {
        let t = tempdir().unwrap();
        let old = file(t.path(), "linux-6.18.59");
        let new = file(t.path(), "linux-6.18.63");
        let i = file(t.path(), "initrd-a");
        let booted = system(t.path(), "booted", &old, &i);
        let current = system(t.path(), "current", &new, &i);
        assert_eq!(reboot_differences(&booted, &current), vec!["kernel"]);
    }

    #[test]
    fn link_missing_on_one_side_counts() {
        let t = tempdir().unwrap();
        let k = file(t.path(), "linux");
        let i = file(t.path(), "initrd");
        let booted = system(t.path(), "booted", &k, &i);
        let current = system(t.path(), "current", &k, &i);
        let m = file(t.path(), "modules");
        symlink(&m, current.join("kernel-modules")).unwrap();
        assert_eq!(
            reboot_differences(&booted, &current),
            vec!["kernel-modules"]
        );
    }

    #[test]
    fn parses_only_pull_request_urls() {
        let json = r#"[{"url":"https://api.github.com/repos/o/r/pulls/7",
            "html_url": "https://github.com/o/r/pull/7",
            "user":{"html_url":"https://github.com/github-actions"},
            "head":{"repo":{"html_url":"https://github.com/o/r"}}}]"#;
        assert_eq!(parse_pull_urls(json), vec!["https://github.com/o/r/pull/7"]);
    }

    #[test]
    fn empty_pull_list_parses_to_nothing() {
        assert!(parse_pull_urls("[]").is_empty());
    }

    #[test]
    fn malformed_repo_skips_the_request() {
        assert!(open_lock_prs("not-a-slug", "update/flake-lock").is_empty());
    }

    #[test]
    fn payloads_name_the_pr_and_the_kernel() {
        let p = Pending {
            reboot: vec!["kernel".into()],
            lock_prs: vec!["https://github.com/o/r/pull/7".into()],
        };
        let out = pending_payloads(&p);
        assert_eq!(out.len(), 2);
        assert_eq!(out[0].summary, "NixOS lock bump awaiting review");
        assert!(out[0].body.contains("https://github.com/o/r/pull/7"));
        assert_eq!(out[1].summary, "NixOS reboot pending");
        assert!(out[1].body.contains("new kernel"));
    }

    #[test]
    fn nothing_pending_sends_nothing() {
        assert!(pending_payloads(&Pending::default()).is_empty());
        assert!(Pending::default().is_empty());
    }
}
