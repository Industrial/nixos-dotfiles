//! `ls` — list directory contents (POSIX-oriented subset).

use std::env;
use std::ffi::OsString;
use std::fs::{self, Metadata};
use std::io::{self, Write};
use std::path::{Path, PathBuf};

use id_effect::Effect;

#[cfg(unix)]
use std::os::unix::fs::MetadataExt;

pub const VERSION: &str = "0.1.0";

#[derive(Debug, Clone)]
pub enum ParsedCli {
    Help,
    Version,
    Run {
        settings: Settings,
        paths: Vec<PathBuf>,
    },
}

#[derive(Debug, Clone)]
pub struct Settings {
    pub all: bool,
    pub long: bool,
    pub one_per_line: bool,
    pub directory: bool,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            all: false,
            long: false,
            one_per_line: false,
            directory: false,
        }
    }
}

pub fn usage() -> &'static str {
    "Usage: ls [OPTION]... [FILE]...\n\n\
List directory contents (subset of POSIX/GNU ls).\n\n\
Options:\n\
  -a, --all            do not ignore entries starting with .\n\
  -d, --directory      list directories themselves, not their contents\n\
  -l                   use a long listing format\n\
  -1                   list one file per line\n\
      --help           display this help and exit\n\
      --version        output version information and exit\n"
}

pub fn parse_args() -> Result<ParsedCli, String> {
    let mut it = env::args_os().skip(1).peekable();
    let mut settings = Settings::default();
    let mut paths: Vec<OsString> = Vec::new();

    while let Some(arg) = it.next() {
        let s = arg.to_string_lossy();
        if s == "--" {
            paths.extend(it);
            break;
        }
        if s.starts_with("--") {
            match s.as_ref() {
                "--help" => return Ok(ParsedCli::Help),
                "--version" => return Ok(ParsedCli::Version),
                "--all" => settings.all = true,
                "--directory" => settings.directory = true,
                _ => return Err(format!("ls: unrecognized option {s:?}")),
            }
            continue;
        }
        if s.starts_with('-') && s != "-" {
            for ch in s.chars().skip(1) {
                match ch {
                    'a' => settings.all = true,
                    'd' => settings.directory = true,
                    'l' => settings.long = true,
                    '1' => settings.one_per_line = true,
                    _ => return Err(format!("ls: invalid option -- {ch}")),
                }
            }
            continue;
        }
        paths.push(arg);
    }

    if paths.is_empty() {
        paths.push(OsString::from("."));
    }

    let paths: Vec<PathBuf> = paths.into_iter().map(PathBuf::from).collect();
    Ok(ParsedCli::Run { settings, paths })
}

fn is_hidden(name: &str) -> bool {
    name.starts_with('.')
}

#[cfg(unix)]
fn mode_string(meta: &Metadata) -> String {
    let mode = meta.mode();
    let ft = meta.file_type();
    let mut s = String::with_capacity(10);
    s.push(if ft.is_dir() {
        'd'
    } else if ft.is_symlink() {
        'l'
    } else {
        '-'
    });
    let rwx = |shift: u32| {
        let m = mode >> shift;
        format!(
            "{}{}{}",
            if m & 4 != 0 { 'r' } else { '-' },
            if m & 2 != 0 { 'w' } else { '-' },
            if m & 1 != 0 { 'x' } else { '-' },
        )
    };
    s.push_str(&rwx(6)); // owner
    s.push_str(&rwx(3)); // group
    s.push_str(&rwx(0)); // other
    s
}

#[cfg(not(unix))]
fn mode_string(_meta: &Metadata) -> String {
    "----------".to_string()
}

fn format_time(meta: &Metadata) -> String {
    if let Ok(t) = meta.modified() {
        if let Ok(d) = t.duration_since(std::time::UNIX_EPOCH) {
            return format!("{}", d.as_secs());
        }
    }
    String::from("?")
}

fn list_one(path: &Path, settings: &Settings) -> io::Result<i32> {
    let exit = 0i32;
    let meta = fs::metadata(path)?;
    if settings.directory || !meta.is_dir() {
        if settings.long {
            let mode = mode_string(&meta);
            #[cfg(unix)]
            let nlink = meta.nlink();
            #[cfg(not(unix))]
            let nlink = 1u64;
            let size = meta.len();
            #[cfg(unix)]
            let uid = meta.uid();
            #[cfg(not(unix))]
            let uid = 0;
            #[cfg(unix)]
            let gid = meta.gid();
            #[cfg(not(unix))]
            let gid = 0;
            let time = format_time(&meta);
            let name = path.file_name().unwrap_or(path.as_os_str());
            println!(
                "{mode} {nlink:>4} {uid:<8} {gid:<8} {size:>8} {time:>10} {}",
                name.to_string_lossy()
            );
        } else {
            let name = path.file_name().unwrap_or(path.as_os_str());
            println!("{}", name.to_string_lossy());
        }
        return Ok(exit);
    }

    let mut entries: Vec<PathBuf> = fs::read_dir(path)?
        .filter_map(|e| e.ok())
        .map(|e| e.path())
        .collect();

    entries.sort_by(|a, b| {
        a.file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .cmp(&b.file_name().unwrap_or_default().to_string_lossy())
    });

    let stdout = io::stdout();
    let mut out = stdout.lock();
    let mut first = true;
    for p in entries {
        let name = p.file_name().unwrap_or_default().to_string_lossy();
        if !settings.all && is_hidden(&name) {
            continue;
        }
        if settings.long {
            let meta = fs::metadata(&p)?;
            let mode = mode_string(&meta);
            #[cfg(unix)]
            let nlink = meta.nlink();
            #[cfg(not(unix))]
            let nlink = 1u64;
            let size = meta.len();
            #[cfg(unix)]
            let uid = meta.uid();
            #[cfg(not(unix))]
            let uid = 0;
            #[cfg(unix)]
            let gid = meta.gid();
            #[cfg(not(unix))]
            let gid = 0;
            let time = format_time(&meta);
            writeln!(
                out,
                "{mode} {nlink:>4} {uid:<8} {gid:<8} {size:>8} {time:>10} {name}"
            )?;
        } else if settings.one_per_line {
            writeln!(out, "{name}")?;
        } else {
            if !first {
                write!(out, "  ")?;
            }
            write!(out, "{name}")?;
            first = false;
        }
    }
    if !settings.long && !settings.one_per_line {
        writeln!(out)?;
    }
    Ok(exit)
}

/// List paths; returns exit code.
pub fn run_ls_sync(settings: &Settings, paths: &[PathBuf]) -> i32 {
    let mut exit = 0i32;
    let multi = paths.len() > 1;
    for (idx, path) in paths.iter().enumerate() {
        if multi {
            println!("{}:", path.display());
        }
        match list_one(path, settings) {
            Ok(e) => exit = exit.max(e),
            Err(e) => {
                eprintln!("ls: {}: {e}", path.display());
                exit = 1;
            }
        }
        if multi && idx + 1 < paths.len() {
            println!();
        }
    }
    exit
}

pub fn ls_effect(settings: Settings, paths: Vec<PathBuf>) -> Effect<i32, String, ()> {
    Effect::new(move |_| Ok(run_ls_sync(&settings, &paths)))
}
