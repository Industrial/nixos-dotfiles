//! `head` — copy the first lines or bytes of each file.

use std::env;
use std::ffi::OsString;
use std::fs::File;
use std::io::{self, BufRead, Read, Write};
use std::path::PathBuf;

use id_effect::Effect;

pub const VERSION: &str = "0.1.0";

#[derive(Debug, Clone)]
pub enum ParsedCli {
    Help,
    Version,
    Run {
        settings: Settings,
        inputs: Vec<Input>,
    },
}

#[derive(Debug, Clone)]
pub struct Settings {
    /// First N lines (`None` means use `bytes` or default 10 lines).
    pub lines: Option<usize>,
    /// First N bytes.
    pub bytes: Option<usize>,
    /// `-q` — never print headers.
    pub quiet: bool,
    /// `-v` — always print headers.
    pub verbose: bool,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            lines: Some(10),
            bytes: None,
            quiet: false,
            verbose: false,
        }
    }
}

#[derive(Debug, Clone)]
pub enum Input {
    Stdin,
    Path(PathBuf),
}

pub fn usage() -> &'static str {
    "Usage: head [OPTION]... [FILE]...\n\n\
Print the first 10 lines of each FILE to standard output; with more than one FILE,\n\
precede each with a header giving the file name.\n\n\
Options:\n\
  -c, --bytes=[-]NUM    print the first NUM bytes\n\
  -n, --lines=[-]NUM    print the first NUM lines (default 10)\n\
  -q, --quiet, --silent never print headers giving file names\n\
  -v, --verbose          always print headers giving file names\n\
      --help             display this help and exit\n\
      --version          output version information and exit\n"
}

fn parse_num(s: &str) -> Result<usize, String> {
    let s = s.trim();
    if s.starts_with('-') && s.len() > 1 {
        return Err("head: negative line/byte counts are not implemented in this build".into());
    }
    s.parse().map_err(|_| format!("head: invalid number {s:?}"))
}

pub fn parse_args() -> Result<ParsedCli, String> {
    let mut it = env::args_os().skip(1).peekable();
    let mut settings = Settings::default();
    let mut files: Vec<OsString> = Vec::new();

    while let Some(arg) = it.next() {
        let s = arg.to_string_lossy();
        if s == "--" {
            files.extend(it);
            break;
        }
        if s.starts_with("--") {
            match s.as_ref() {
                "--help" => return Ok(ParsedCli::Help),
                "--version" => return Ok(ParsedCli::Version),
                "--quiet" | "--silent" => {
                    settings.quiet = true;
                }
                "--verbose" => settings.verbose = true,
                long if long.starts_with("--bytes=") => {
                    let v = &long["--bytes=".len()..];
                    settings.bytes = Some(parse_num(v)?);
                    settings.lines = None;
                }
                long if long.starts_with("--lines=") => {
                    let v = &long["--lines=".len()..];
                    settings.lines = Some(parse_num(v)?);
                    settings.bytes = None;
                }
                "--bytes" => {
                    let v = it
                        .next()
                        .ok_or_else(|| "head: option requires an argument --bytes".to_string())?;
                    settings.bytes = Some(parse_num(&v.to_string_lossy())?);
                    settings.lines = None;
                }
                "--lines" => {
                    let v = it
                        .next()
                        .ok_or_else(|| "head: option requires an argument --lines".to_string())?;
                    settings.lines = Some(parse_num(&v.to_string_lossy())?);
                    settings.bytes = None;
                }
                _ => return Err(format!("head: unrecognized option {s:?}")),
            }
            continue;
        }
        if s.starts_with('-') && s != "-" {
            let mut chars = s.chars().skip(1);
            while let Some(ch) = chars.next() {
                match ch {
                    'c' => {
                        let rest: String = chars.collect();
                        let v = if rest.is_empty() {
                            it.next()
                                .ok_or_else(|| {
                                    "head: option requires an argument for -c".to_string()
                                })?
                                .to_string_lossy()
                                .into_owned()
                        } else {
                            rest
                        };
                        settings.bytes = Some(parse_num(&v)?);
                        settings.lines = None;
                        break;
                    }
                    'n' => {
                        let rest: String = chars.collect();
                        let v = if rest.is_empty() {
                            it.next()
                                .ok_or_else(|| {
                                    "head: option requires an argument for -n".to_string()
                                })?
                                .to_string_lossy()
                                .into_owned()
                        } else {
                            rest
                        };
                        settings.lines = Some(parse_num(&v)?);
                        settings.bytes = None;
                        break;
                    }
                    'q' => settings.quiet = true,
                    'v' => settings.verbose = true,
                    _ => return Err(format!("head: invalid option -- {ch}")),
                }
            }
            continue;
        }
        files.push(arg);
    }

    let inputs: Vec<Input> = if files.is_empty() {
        vec![Input::Stdin]
    } else {
        files
            .into_iter()
            .map(|p| {
                if p == "-" {
                    Input::Stdin
                } else {
                    Input::Path(PathBuf::from(p))
                }
            })
            .collect()
    };

    Ok(ParsedCli::Run { settings, inputs })
}

fn head_bytes<R: Read>(mut reader: R, max: usize, mut out: impl Write) -> io::Result<()> {
    let mut buf = [0u8; 8192];
    let mut remaining = max;
    while remaining > 0 {
        let chunk = buf.len().min(remaining);
        let n = reader.read(&mut buf[..chunk])?;
        if n == 0 {
            break;
        }
        out.write_all(&buf[..n])?;
        remaining -= n;
    }
    Ok(())
}

fn head_lines<R: Read>(reader: R, max: usize, mut out: impl Write) -> io::Result<()> {
    let mut buf = Vec::new();
    let mut reader = io::BufReader::new(reader);
    let mut lines = 0usize;
    loop {
        buf.clear();
        let n = reader.read_until(b'\n', &mut buf)?;
        if n == 0 {
            break;
        }
        out.write_all(&buf)?;
        lines += 1;
        if lines >= max {
            break;
        }
    }
    Ok(())
}

fn copy_head(settings: &Settings, reader: impl Read) -> io::Result<()> {
    let stdout = io::stdout();
    let out = stdout.lock();
    if let Some(b) = settings.bytes {
        head_bytes(reader, b, out)
    } else {
        let n = settings.lines.unwrap_or(10);
        head_lines(reader, n, out)
    }
}

/// Process inputs; returns exit code.
pub fn run_head_sync(settings: &Settings, inputs: &[Input]) -> i32 {
    let mut exit = 0i32;
    let multi = inputs.len() > 1;
    let print_headers = if settings.quiet {
        false
    } else if settings.verbose {
        true
    } else {
        multi
    };

    for input in inputs {
        match input {
            Input::Stdin => {
                if print_headers {
                    let _ = writeln!(io::stdout(), "==> standard input <==");
                }
                if let Err(e) = copy_head(settings, io::stdin()) {
                    eprintln!("head: stdin: {e}");
                    exit = 1;
                }
            }
            Input::Path(p) => {
                if print_headers {
                    let _ = writeln!(io::stdout(), "==> {} <==", p.display());
                }
                match File::open(p) {
                    Ok(f) => {
                        if let Err(e) = copy_head(settings, f) {
                            eprintln!("head: {}: {e}", p.display());
                            exit = 1;
                        }
                    }
                    Err(e) => {
                        eprintln!("head: {}: {e}", p.display());
                        exit = 1;
                    }
                }
            }
        }
    }
    exit
}

pub fn head_effect(settings: Settings, inputs: Vec<Input>) -> Effect<i32, String, ()> {
    Effect::new(move |_| Ok(run_head_sync(&settings, &inputs)))
}
