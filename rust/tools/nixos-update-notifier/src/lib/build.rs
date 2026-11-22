use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use thiserror::Error;

use crate::config::Differ;
use crate::diff::{DiffError, PackageChange, parse_diff_closures, parse_vdiff_json};

#[derive(Debug, Error)]
pub enum BuildError {
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
    #[error("nix build failed: {0}")]
    BuildFailed(String),
    #[error("{differ} failed: {stderr}")]
    DiffFailed {
        differ: &'static str,
        stderr: String,
    },
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

/// Diff two closures with the configured differ: `vdiff --json` by default, or
/// `nix store diff-closures` (the rollback, `--differ nix`).
pub fn diff_closures(
    differ: Differ,
    vdiff: &Path,
    before: &Path,
    after: &Path,
) -> Result<Vec<PackageChange>, BuildError> {
    let (name, mut command) = match differ {
        Differ::Vdiff => {
            let mut c = Command::new(vdiff);
            c.arg("--json");
            ("vdiff --json", c)
        }
        Differ::Nix => {
            let mut c = Command::new("nix");
            c.args([
                "--extra-experimental-features",
                "nix-command flakes",
                "store",
                "diff-closures",
            ]);
            ("nix store diff-closures", c)
        }
    };
    let output = command.arg(before).arg(after).output()?;

    if !output.status.success() {
        return Err(BuildError::DiffFailed {
            differ: name,
            stderr: String::from_utf8_lossy(&output.stderr).trim().to_string(),
        });
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    Ok(match differ {
        Differ::Vdiff => parse_vdiff_json(&stdout)?,
        Differ::Nix => parse_diff_closures(&stdout)?,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    use std::os::unix::fs::PermissionsExt;

    /// A stand-in vdiff: refuses anything but `--json <old> <new>`, then prints `json`.
    fn fake_vdiff(dir: &Path, json: &str) -> PathBuf {
        fs::write(dir.join("out.json"), json).unwrap();
        let bin = dir.join("vdiff");
        fs::write(
            &bin,
            format!(
                "#!/bin/sh\n[ \"$1\" = --json ] && [ $# -eq 3 ] || exit 2\nexec cat '{}'\n",
                dir.join("out.json").display()
            ),
        )
        .unwrap();
        fs::set_permissions(&bin, fs::Permissions::from_mode(0o755)).unwrap();
        bin
    }

    #[test]
    fn vdiff_differ_runs_vdiff_json_and_parses_it() {
        let t = tempfile::tempdir().unwrap();
        let bin = fake_vdiff(
            t.path(),
            include_str!("../../tests/fixtures/vdiff-drakkar-494-520.json"),
        );
        let changes =
            diff_closures(Differ::Vdiff, &bin, Path::new("/old"), Path::new("/new")).unwrap();
        assert_eq!(changes.len(), 9);
        assert_eq!(changes[0].to_string(), "voltaic: 0.2.1 → 0.3.0");
    }

    #[test]
    fn a_failing_vdiff_names_the_differ() {
        let t = tempfile::tempdir().unwrap();
        let bin = t.path().join("vdiff");
        fs::write(&bin, "#!/bin/sh\necho 'no such path' >&2\nexit 1\n").unwrap();
        fs::set_permissions(&bin, fs::Permissions::from_mode(0o755)).unwrap();
        let err =
            diff_closures(Differ::Vdiff, &bin, Path::new("/old"), Path::new("/new")).unwrap_err();
        assert_eq!(err.to_string(), "vdiff --json failed: no such path");
    }

    #[test]
    fn available_memory_mib_reads_proc() {
        let mib = available_memory_mib().unwrap();
        assert!(mib > 0);
    }
}
