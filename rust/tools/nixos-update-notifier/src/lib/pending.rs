//! What is waiting on the operator, beyond "upstream moved".
//!
//! Under the update policy (docs/adr/0006-update-policy.md) a lock bump arrives as a
//! pull request, comin converges hosts from merged main, and nothing reboots on its own.
//! So the two things only the operator can do are: review the open lock-bump PR, and
//! reboot into a kernel that comin already switched to. This module detects both.

use std::fs;
use std::path::Path;
use std::process::Command;

use serde::Deserialize;

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

/// One open pull request, as `GET /repos/{repo}/pulls` lists it. Only the fields the
/// lookup reads; unknown fields are ignored.
#[derive(Debug, Deserialize)]
struct Pull {
    html_url: String,
    head: Head,
}

#[derive(Debug, Deserialize)]
struct Head {
    #[serde(rename = "ref")]
    branch: String,
    /// `null` when the head repository was deleted (a fork that is gone).
    repo: Option<HeadRepo>,
}

#[derive(Debug, Deserialize)]
struct HeadRepo {
    full_name: String,
}

/// Is `head` a lock-bump branch: the legacy single PR's `branch` itself, or one of
/// vbump's per-input `<branch>-<input>` (`update/flake-lock-nixpkgs`, GH-200)?
pub fn is_lock_branch(head: &str, branch: &str) -> bool {
    head.strip_prefix(branch)
        .is_some_and(|rest| rest.is_empty() || rest.starts_with('-'))
}

/// Lock-bump PR URLs out of a GitHub `GET /repos/{repo}/pulls` JSON response: PRs whose
/// head is a lock branch (see [`is_lock_branch`]) **of `repo` itself**. A fork's PR from
/// a branch of the same name is not a lock bump. Malformed JSON yields nothing.
pub fn parse_lock_pulls(json: &str, repo: &str, branch: &str) -> Vec<String> {
    let Ok(pulls) = serde_json::from_str::<Vec<Pull>>(json) else {
        return Vec::new();
    };
    pulls
        .into_iter()
        .filter(|p| {
            is_lock_branch(&p.head.branch, branch)
                && p.head
                    .repo
                    .as_ref()
                    .is_some_and(|r| r.full_name.eq_ignore_ascii_case(repo))
        })
        .map(|p| p.html_url)
        .collect()
}

/// The one request the lookup makes: every open PR of `repo`, filtered here on
/// `head.ref`, because GitHub's `head=` filter only matches a branch exactly and vbump
/// opens one branch per input. `per_page=100` is GitHub's maximum, so a single page
/// holds every open PR unless the repository has more than 100 open at once.
pub fn open_pulls_url(repo: &str) -> String {
    format!("https://api.github.com/repos/{repo}/pulls?state=open&per_page=100")
}

/// Open lock-bump PRs (`branch`, or vbump's `branch-<input>`) on public `repo`
/// (`owner/name`), via the unauthenticated GitHub API. Any failure (offline, rate limit,
/// curl missing) yields an empty list: this is a courtesy notice, never a reason for the
/// timer unit to fail.
pub fn open_lock_prs(repo: &str, branch: &str) -> Vec<String> {
    if !repo.contains('/') {
        return Vec::new();
    }
    let url = open_pulls_url(repo);
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
        Ok(o) if o.status.success() => {
            parse_lock_pulls(&String::from_utf8_lossy(&o.stdout), repo, branch)
        }
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

    const REPO: &str = "Industrial/nixos-dotfiles";
    const BRANCH: &str = "update/flake-lock";

    /// One PR as the pulls API lists it, with the nested `html_url`s a regex would trip on.
    fn pull(n: u32, head_ref: &str, head_repo: Option<&str>) -> String {
        let repo = head_repo.map_or("null".to_string(), |r| {
            format!(r#"{{"full_name":"{r}","html_url":"https://github.com/{r}"}}"#)
        });
        format!(
            r#"{{"url":"https://api.github.com/repos/{REPO}/pulls/{n}",
            "html_url":"https://github.com/{REPO}/pull/{n}",
            "user":{{"login":"vbump[bot]","html_url":"https://github.com/apps/vbump"}},
            "head":{{"label":"x:{head_ref}","ref":"{head_ref}","repo":{repo}}},
            "base":{{"ref":"main","repo":{{"full_name":"{REPO}"}}}}}}"#
        )
    }

    fn page(pulls: &[String]) -> String {
        format!("[{}]", pulls.join(","))
    }

    fn url(n: u32) -> String {
        format!("https://github.com/{REPO}/pull/{n}")
    }

    #[test]
    fn the_legacy_single_branch_is_a_lock_pr() {
        let json = page(&[pull(7, "update/flake-lock", Some(REPO))]);
        assert_eq!(parse_lock_pulls(&json, REPO, BRANCH), vec![url(7)]);
    }

    #[test]
    fn a_vbump_per_input_branch_is_a_lock_pr() {
        let json = page(&[
            pull(8, "update/flake-lock-nixpkgs", Some(REPO)),
            pull(9, "update/flake-lock-nix-vscode-extensions", Some(REPO)),
        ]);
        assert_eq!(parse_lock_pulls(&json, REPO, BRANCH), vec![url(8), url(9)]);
    }

    #[test]
    fn an_unrelated_branch_is_not() {
        let json = page(&[
            pull(10, "feat/gh-207-notifier-vdiff", Some(REPO)),
            // Shares the prefix, but is not `<branch>` or `<branch>-<input>`.
            pull(11, "update/flake-lockfile-docs", Some(REPO)),
            pull(12, "fix/update/flake-lock", Some(REPO)),
        ]);
        assert!(parse_lock_pulls(&json, REPO, BRANCH).is_empty());
    }

    #[test]
    fn a_forks_branch_of_the_same_name_is_refused() {
        let json = page(&[
            pull(13, "update/flake-lock", Some("someone/nixos-dotfiles")),
            pull(
                14,
                "update/flake-lock-nixpkgs",
                Some("someone/nixos-dotfiles"),
            ),
            // The fork was deleted: GitHub reports its head repo as null.
            pull(15, "update/flake-lock", None),
        ]);
        assert!(parse_lock_pulls(&json, REPO, BRANCH).is_empty());
    }

    #[test]
    fn a_mixed_page_keeps_only_this_repos_lock_prs_in_order() {
        let json = page(&[
            pull(20, "update/flake-lock-comin", Some(REPO)),
            pull(21, "feat/x", Some(REPO)),
            pull(22, "update/flake-lock", Some("fork/nixos-dotfiles")),
            pull(23, "update/flake-lock", Some(REPO)),
        ]);
        assert_eq!(
            parse_lock_pulls(&json, REPO, BRANCH),
            vec![url(20), url(23)]
        );
    }

    #[test]
    fn lock_branch_matching() {
        assert!(is_lock_branch("update/flake-lock", BRANCH));
        assert!(is_lock_branch("update/flake-lock-nixpkgs", BRANCH));
        assert!(!is_lock_branch("update/flake-locks", BRANCH));
        assert!(!is_lock_branch("update/flake", BRANCH));
        assert!(!is_lock_branch("", BRANCH));
    }

    #[test]
    fn empty_or_malformed_responses_parse_to_nothing() {
        assert!(parse_lock_pulls("[]", REPO, BRANCH).is_empty());
        // A rate-limit error body is an object, not a list.
        assert!(
            parse_lock_pulls(r#"{"message":"API rate limit exceeded"}"#, REPO, BRANCH).is_empty()
        );
        assert!(parse_lock_pulls("not json", REPO, BRANCH).is_empty());
    }

    #[test]
    fn one_request_lists_every_open_pr_a_page_at_a_time_of_100() {
        // No `head=` filter: GitHub matches it exactly, which hides vbump's branches.
        assert_eq!(
            open_pulls_url(REPO),
            "https://api.github.com/repos/Industrial/nixos-dotfiles/pulls?state=open&per_page=100"
        );
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
