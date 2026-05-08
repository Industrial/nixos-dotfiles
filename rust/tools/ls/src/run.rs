//! Listing orchestration with injectable stdout/stderr (testable).

use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

use chrono::Local;

use crate::args::Settings;
use crate::format::{
    blocks_512, format_mtime, long_name, mode_string, nlink, size_or_device, uid_gid_names,
};

fn visible(name: &str, settings: &Settings) -> bool {
    if !name.starts_with('.') {
        return true;
    }
    if settings.all {
        return true;
    }
    if settings.almost_all && name != "." && name != ".." {
        return true;
    }
    false
}

fn collect_sorted_entries(dir: &Path, settings: &Settings) -> std::io::Result<Vec<PathBuf>> {
    let mut entries: Vec<PathBuf> = fs::read_dir(dir)?
        .filter_map(|e| e.ok())
        .map(|e| e.path())
        .filter(|p| {
            let name = p.file_name().and_then(|n| n.to_str()).unwrap_or("");
            visible(name, settings)
        })
        .collect();
    entries.sort_by(|a, b| {
        let an = a.file_name().unwrap_or_default();
        let bn = b.file_name().unwrap_or_default();
        an.to_string_lossy().cmp(&bn.to_string_lossy())
    });
    Ok(entries)
}

fn write_long<W: Write>(
    out: &mut W,
    path: &Path,
    meta: &fs::Metadata,
    now: chrono::DateTime<Local>,
) -> std::io::Result<()> {
    let mode = mode_string(meta);
    let nl = nlink(meta);
    let (user, group) = uid_gid_names(meta);
    let size_col = size_or_device(meta);
    let mtime = format_mtime(meta, now);
    let name = long_name(path, meta);
    writeln!(
        out,
        "{mode} {nl} {user} {group} {size_col} {mtime} {name}"
    )?;
    Ok(())
}

fn list_one<W: Write, E: Write>(
    path: &Path,
    settings: &Settings,
    out: &mut W,
    _err: &mut E,
    now: chrono::DateTime<Local>,
) -> std::io::Result<i32> {
    let exit = 0i32;
    let meta = fs::metadata(path)?;
    if settings.directory || !meta.is_dir() {
        if settings.long {
            let sm = fs::symlink_metadata(path)?;
            write_long(out, path, &sm, now)?;
        } else {
            let name = path.file_name().unwrap_or(path.as_os_str());
            writeln!(out, "{}", name.to_string_lossy())?;
        }
        return Ok(exit);
    }

    let entries = collect_sorted_entries(path, settings)?;

    if settings.long {
        let total_kb: u64 = entries
            .iter()
            .filter_map(|p| fs::symlink_metadata(p).ok())
            .map(|m| blocks_512(&m))
            .sum::<u64>()
            / 2;
        writeln!(out, "total {total_kb}")?;
        for p in entries {
            let sm = fs::symlink_metadata(&p)?;
            write_long(out, &p, &sm, now)?;
        }
        return Ok(exit);
    }

    let mut first = true;
    for p in entries {
        let name = p.file_name().unwrap_or_default().to_string_lossy();
        if settings.one_per_line {
            writeln!(out, "{name}")?;
        } else {
            if !first {
                write!(out, "  ")?;
            }
            write!(out, "{name}")?;
            first = false;
        }
    }
    if !settings.one_per_line {
        writeln!(out)?;
    }
    Ok(exit)
}

/// List paths; returns exit code. Side effects go to `out` / `err`.
pub fn run_ls_with_io<W, E>(settings: &Settings, paths: &[PathBuf], out: &mut W, err: &mut E) -> i32
where
    W: Write,
    E: Write,
{
    let now = Local::now();
    let mut exit = 0i32;
    let multi = paths.len() > 1;
    for (idx, path) in paths.iter().enumerate() {
        if multi {
            let _ = writeln!(out, "{}:", path.display());
        }
        match list_one(path, settings, out, err, now) {
            Ok(e) => exit = exit.max(e),
            Err(e) => {
                let _ = writeln!(err, "ls: {}: {e}", path.display());
                exit = 1;
            }
        }
        if multi && idx + 1 < paths.len() {
            let _ = writeln!(out);
        }
    }
    exit
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;
    use crate::args::Settings;
    use std::io::Cursor;
    use std::os::unix::fs::symlink;

    mod run_ls_with_io {
        use super::*;

        mod with_symlink_in_directory {
            use super::*;

            #[test]
            fn long_lists_arrow_target_using_lstat() {
                let tmp = tempfile::tempdir().expect("tmp");
                let dir = tmp.path();
                fs::write(dir.join("target"), b"hi").unwrap();
                symlink("target", dir.join("link")).unwrap();

                let settings = Settings {
                    long: true,
                    ..Default::default()
                };
                let mut stdout = Cursor::new(Vec::new());
                let mut stderr = Cursor::new(Vec::new());
                let code = run_ls_with_io(&settings, &[dir.to_path_buf()], &mut stdout, &mut stderr);
                assert_eq!(code, 0);
                let s = String::from_utf8(stdout.into_inner()).unwrap();
                assert!(
                    s.contains("link -> target"),
                    "expected arrow in long output, got:\n{s}"
                );
                assert!(s.lines().any(|l| l.starts_with('l') && l.contains("link ->")));
            }
        }

        mod with_almost_all {
            use super::*;

            #[test]
            fn hides_dot_and_dot_dot_without_all() {
                let tmp = tempfile::tempdir().expect("tmp");
                let dir = tmp.path();
                fs::write(dir.join("vis"), b"").unwrap();

                let settings = Settings {
                    almost_all: true,
                    one_per_line: true,
                    ..Default::default()
                };
                let mut stdout = Cursor::new(Vec::new());
                let mut stderr = Cursor::new(Vec::new());
                run_ls_with_io(&settings, &[dir.to_path_buf()], &mut stdout, &mut stderr);
                let s = String::from_utf8(stdout.into_inner()).unwrap();
                assert!(s.contains("vis"));
                assert!(!s.lines().any(|l| l.trim() == "."));
                assert!(!s.lines().any(|l| l.trim() == ".."));
            }
        }
    }
}
