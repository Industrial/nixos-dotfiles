use std::path::{Path, PathBuf};

use clap::Parser;

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

    /// Branch the update-flake-lock workflow opens its PR from.
    #[arg(
        long,
        default_value = "update/flake-lock",
        env = "NIXOS_UPDATE_LOCK_BRANCH"
    )]
    pub lock_branch: String,

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
