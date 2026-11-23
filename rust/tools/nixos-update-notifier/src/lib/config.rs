use std::path::{Path, PathBuf};

use clap::{Parser, ValueEnum};

/// The closure differ behind the package list.
#[derive(Debug, Clone, Copy, PartialEq, Eq, ValueEnum)]
pub enum Differ {
    /// `vdiff --json` (rust/tools/vdiff): reads the store database directly.
    Vdiff,
    /// `nix store diff-closures`: the rollback.
    Nix,
}

/// Check for NixOS flake updates and notify with exact package changes.
#[derive(Debug, Clone, Parser)]
#[command(name = "nixos-update-notifier", version, about)]
pub struct Config {
    /// Flake directory (contains flake.nix + flake.lock). Default: the unified root
    /// flake at `$HOME/.dotfiles`.
    /// (An empty-string default is rejected by clap's PathBuf parser, so this is an
    /// Option that `main` fills in.)
    #[arg(long, env = "NIXOS_UPDATE_FLAKE")]
    pub flake: Option<PathBuf>,

    /// NixOS configuration attribute name (usually the hostname).
    #[arg(long, env = "NIXOS_UPDATE_HOSTNAME", default_value = "")]
    pub hostname: String,

    /// Closure to diff against (default: running system).
    #[arg(
        long,
        default_value = "/run/current-system",
        env = "NIXOS_UPDATE_CURRENT"
    )]
    pub current_system: PathBuf,

    /// Booted system, compared with `current_system` to detect a pending reboot.
    #[arg(
        long,
        default_value = "/run/booted-system",
        env = "NIXOS_UPDATE_BOOTED"
    )]
    pub booted_system: PathBuf,

    /// Public GitHub repository (`owner/name`) whose open lock-bump PRs to report.
    /// Empty disables the lookup.
    #[arg(long, default_value = "", env = "NIXOS_UPDATE_GITHUB_REPO")]
    pub github_repo: String,

    /// Lock-bump branch: the old whole-lock workflow's single PR branch (deleted in GH-247), and the prefix
    /// of vbump's per-input `<branch>-<input>` branches. Both count as a lock bump.
    #[arg(
        long,
        default_value = "update/flake-lock",
        env = "NIXOS_UPDATE_LOCK_BRANCH"
    )]
    pub lock_branch: String,

    /// Which closure differ lists the package changes: `vdiff` (`vdiff --json`, the
    /// default) or `nix` (`nix store diff-closures`, kept as the rollback).
    #[arg(long, value_enum, default_value_t = Differ::Vdiff, env = "NIXOS_UPDATE_DIFFER")]
    pub differ: Differ,

    /// The vdiff binary. The Nix package sets this to vdiff's absolute store path.
    #[arg(long, default_value = "vdiff", env = "NIXOS_UPDATE_VDIFF")]
    pub vdiff: PathBuf,

    /// Minimum available memory (MiB) required before building the new closure.
    #[arg(long, default_value_t = 4096, env = "NIXOS_UPDATE_MIN_MEM_MIB")]
    pub min_mem_mib: u64,

    /// Max characters per notification body (GNOME truncates large bodies).
    #[arg(long, default_value_t = 900, env = "NIXOS_UPDATE_BODY_LIMIT")]
    pub body_limit: usize,

    /// Print results but do not send desktop notifications.
    #[arg(long, default_value_t = false)]
    pub no_notify: bool,

    /// Skip building / diffing; only report whether the lock file would change.
    #[arg(long, default_value_t = false)]
    pub lock_only: bool,
}

impl Config {
    /// The flake directory; `main` always sets it, so the fallback is only for library
    /// callers that build a `Config` by hand.
    pub fn flake_dir(&self) -> &Path {
        self.flake.as_deref().unwrap_or(Path::new("."))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn vdiff_is_the_default_differ() {
        let config = Config::parse_from(["nixos-update-notifier"]);
        assert_eq!(config.differ, Differ::Vdiff);
        assert_eq!(config.vdiff, PathBuf::from("vdiff"));
    }

    #[test]
    fn nix_differ_is_the_rollback() {
        let config = Config::parse_from(["nixos-update-notifier", "--differ", "nix"]);
        assert_eq!(config.differ, Differ::Nix);
    }
}
