use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use thiserror::Error;

#[derive(Debug, Error)]
pub enum LockError {
    #[error("flake directory does not exist: {0}")]
    MissingFlakeDir(PathBuf),
    #[error("flake.lock not found in {0}")]
    MissingLock(PathBuf),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
    #[error("nix flake update failed: {0}")]
    UpdateFailed(String),
}

/// Write an updated flake.lock to `output` without modifying the flake dir lock.
pub fn update_lock_to(flake_dir: &Path, output: &Path) -> Result<(), LockError> {
    if !flake_dir.is_dir() {
        return Err(LockError::MissingFlakeDir(flake_dir.to_path_buf()));
    }
    let current = flake_dir.join("flake.lock");
    if !current.is_file() {
        return Err(LockError::MissingLock(flake_dir.to_path_buf()));
    }

    let status = Command::new("nix")
        .args([
            "--extra-experimental-features",
            "nix-command flakes",
            "flake",
            "update",
            "--output-lock-file",
        ])
        .arg(output)
        .current_dir(flake_dir)
        .output()?;

    if !status.status.success() {
        return Err(LockError::UpdateFailed(
            String::from_utf8_lossy(&status.stderr).trim().to_string(),
        ));
    }
    Ok(())
}

/// True when the candidate lock differs from the flake's current lock.
pub fn lock_changed(flake_dir: &Path, candidate: &Path) -> Result<bool, LockError> {
    let current = fs::read(flake_dir.join("flake.lock"))?;
    let next = fs::read(candidate)?;
    Ok(current != next)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::tempdir;

    #[test]
    fn lock_changed_detects_difference() {
        let dir = tempdir().unwrap();
        let flake = dir.path();
        fs::write(flake.join("flake.lock"), b"old").unwrap();
        let cand = dir.path().join("new.lock");
        fs::write(&cand, b"new").unwrap();
        assert!(lock_changed(flake, &cand).unwrap());
    }

    #[test]
    fn lock_changed_false_when_identical() {
        let dir = tempdir().unwrap();
        let flake = dir.path();
        fs::write(flake.join("flake.lock"), b"same").unwrap();
        let cand = dir.path().join("new.lock");
        fs::write(&cand, b"same").unwrap();
        assert!(!lock_changed(flake, &cand).unwrap());
    }
}
