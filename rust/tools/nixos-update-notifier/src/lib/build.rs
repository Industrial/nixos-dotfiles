use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use thiserror::Error;

use crate::diff::{DiffError, PackageChange, parse_diff_closures};

#[derive(Debug, Error)]
pub enum BuildError {
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
    #[error("nix build failed: {0}")]
    BuildFailed(String),
    #[error("nix store diff-closures failed: {0}")]
    DiffFailed(String),
    #[error("{0}")]
    DiffParse(#[from] DiffError),
    #[error("could not read MemAvailable from /proc/meminfo")]
    MemInfo,
}

/// Available memory in MiB from `/proc/meminfo`.
pub fn available_memory_mib() -> Result<u64, BuildError> {
    let text = fs::read_to_string("/proc/meminfo")?;
    for line in text.lines() {
        if let Some(rest) = line.strip_prefix("MemAvailable:") {
            let kib: u64 = rest
                .split_whitespace()
                .next()
                .ok_or(BuildError::MemInfo)?
                .parse()
                .map_err(|_| BuildError::MemInfo)?;
            return Ok(kib / 1024);
        }
    }
    Err(BuildError::MemInfo)
}

/// Build the NixOS system toplevel using `reference_lock`, return the store path.
pub fn build_toplevel(
    flake_dir: &Path,
    hostname: &str,
    reference_lock: &Path,
    out_link: &Path,
) -> Result<PathBuf, BuildError> {
    let attr = format!(".#nixosConfigurations.{hostname}.config.system.build.toplevel");
    let output = Command::new("nix")
        .args([
            "--extra-experimental-features",
            "nix-command flakes",
            "build",
            "--print-out-paths",
            "--reference-lock-file",
        ])
        .arg(reference_lock)
        .arg(&attr)
        .arg("--out-link")
        .arg(out_link)
        .current_dir(flake_dir)
        .output()?;

    if !output.status.success() {
        return Err(BuildError::BuildFailed(
            String::from_utf8_lossy(&output.stderr).trim().to_string(),
        ));
    }

    // Prefer the out-link when present; otherwise parse printed path.
    if out_link.exists() {
        return Ok(fs::canonicalize(out_link)?);
    }

    let path = String::from_utf8_lossy(&output.stdout)
        .lines()
        .map(str::trim)
        .find(|l| l.starts_with("/nix/store/"))
        .ok_or_else(|| BuildError::BuildFailed("nix build produced no store path".into()))?
        .to_string();
    Ok(PathBuf::from(path))
}

/// Diff two closures with `nix store diff-closures`.
pub fn diff_closures(before: &Path, after: &Path) -> Result<Vec<PackageChange>, BuildError> {
    let output = Command::new("nix")
        .args([
            "--extra-experimental-features",
            "nix-command flakes",
            "store",
            "diff-closures",
        ])
        .arg(before)
        .arg(after)
        .output()?;

    if !output.status.success() {
        return Err(BuildError::DiffFailed(
            String::from_utf8_lossy(&output.stderr).trim().to_string(),
        ));
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    Ok(parse_diff_closures(&stdout)?)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn available_memory_mib_reads_proc() {
        let mib = available_memory_mib().unwrap();
        assert!(mib > 0);
    }
}
