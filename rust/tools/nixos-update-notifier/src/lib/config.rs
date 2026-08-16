use std::path::PathBuf;

use clap::Parser;

/// Check for NixOS flake updates and notify with exact package changes.
#[derive(Debug, Clone, Parser)]
#[command(name = "nixos-update-notifier", version, about)]
pub struct Config {
    /// Host flake directory (contains flake.nix + flake.lock).
    #[arg(long, env = "NIXOS_UPDATE_FLAKE", default_value = "")]
    pub flake: PathBuf,

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
