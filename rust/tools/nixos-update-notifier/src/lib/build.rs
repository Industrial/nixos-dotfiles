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

    /// Install an executable stand-in at `bin` without this process ever holding a
    /// writable fd on it (GH-282).
    ///
    /// `fs::write` + `set_permissions` + exec is racy under the parallel test
    /// harness: while one test thread has the script open for writing, another
    /// thread's `Command::spawn` clones the fd table, and its child keeps a copy of
    /// that write fd until its own `execve` closes it (O_CLOEXEC only acts at exec).
    /// If the first thread execs its script inside that window, the kernel sees a
    /// writer on the inode and fails with ETXTBSY. Closing, syncing or renaming in
    /// this process does not help: the copy lives in the other child and pins the
    /// inode, not the name. So the source goes to a data file that is never exec'd,
    /// and the executable is created by `install`, a separate process whose write
    /// fd no sibling can inherit. `status()` waits for it to exit, so every writer
    /// of `bin` is gone before anyone execs it.
    fn install_stand_in(bin: &Path, script: &str) {
        let src = bin.with_extension("sh");
        fs::write(&src, script).unwrap();
        let status = Command::new("install")
            .arg("-m")
            .arg("0755")
            .arg(&src)
            .arg(bin)
            .status()
            .unwrap();
        assert!(
            status.success(),
            "install {} failed: {status}",
            bin.display()
        );
    }

    /// A stand-in vdiff: refuses anything but `--json <old> <new>`, then prints `json`.
    fn fake_vdiff(dir: &Path, json: &str) -> PathBuf {
        fs::write(dir.join("out.json"), json).unwrap();
        let bin = dir.join("vdiff");
        install_stand_in(
            &bin,
            &format!(
                "#!/bin/sh\n[ \"$1\" = --json ] && [ $# -eq 3 ] || exit 2\nexec cat '{}'\n",
                dir.join("out.json").display()
            ),
        );
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
        install_stand_in(&bin, "#!/bin/sh\necho 'no such path' >&2\nexit 1\n");
        let err =
            diff_closures(Differ::Vdiff, &bin, Path::new("/old"), Path::new("/new")).unwrap_err();
        assert_eq!(err.to_string(), "vdiff --json failed: no such path");
    }

    /// Regression guard for GH-282: threads create and exec stand-ins at once, so
    /// creations overlap other threads' spawns. The old write-then-exec helper hits
    /// ETXTBSY here; with `install_stand_in` this process never holds a writer on a
    /// stand-in, so no spawn can inherit one.
    #[test]
    fn stand_ins_survive_concurrent_spawns() {
        let t = tempfile::tempdir().unwrap();
        std::thread::scope(|s| {
            for thread in 0..8 {
                let root = t.path();
                s.spawn(move || {
                    for i in 0..25 {
                        let dir = root.join(format!("{thread}-{i}"));
                        fs::create_dir(&dir).unwrap();
                        let bin = dir.join("stand-in");
                        install_stand_in(&bin, "#!/bin/sh\nexit 0\n");
                        let status = Command::new(&bin).status().unwrap();
                        assert!(status.success());
                    }
                });
            }
        });
    }

    #[test]
    fn available_memory_mib_reads_proc() {
        let mib = available_memory_mib().unwrap();
        assert!(mib > 0);
    }
}
