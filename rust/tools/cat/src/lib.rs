//! `cat` — concatenate files to stdout (POSIX-oriented subset).

use std::env;
use std::ffi::OsString;
use std::fs::File;
use std::io::{self, BufRead, BufReader, Write};
use std::path::PathBuf;

use id_effect::Effect;

/// `--version` string.
pub const VERSION: &str = "0.1.0";

/// Parsed CLI (help/version/run).
#[derive(Debug, Clone)]
pub enum ParsedCli {
    Help,
    Version,
    Run {
        settings: Settings,
        inputs: Vec<Input>,
    },
}

#[derive(Debug, Clone, Default)]
pub struct Settings {
    pub number_all: bool,
    pub number_nonblank: bool,
    pub squeeze_blank: bool,
    pub show_ends: bool,
    pub show_tabs: bool,
}

#[derive(Debug, Clone)]
pub enum Input {
    Stdin,
    Path(PathBuf),
}

pub fn usage() -> &'static str {
    "Usage: cat [OPTION]... [FILE]...\n\n\
Concatenate FILE(s) to standard output. With no FILE, or when FILE is -, read stdin.\n\n\
Options:\n\
  -n, --number           number all output lines\n\
  -b, --number-nonblank  number nonempty output lines, overrides -n\n\
  -s, --squeeze-blank    suppress repeated empty output lines\n\
  -E, --show-ends        display $ at end of each line\n\
  -T, --show-tabs        display TAB characters as ^I\n\
  -u                     (ignored; POSIX unbuffered)\n\
      --help             display this help and exit\n\
      --version          output version information and exit\n"
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
                "--number" => settings.number_all = true,
                "--number-nonblank" => settings.number_nonblank = true,
                "--squeeze-blank" => settings.squeeze_blank = true,
                "--show-ends" => settings.show_ends = true,
                "--show-tabs" => settings.show_tabs = true,
                _ => return Err(format!("cat: unrecognized option {s:?}")),
            }
            continue;
        }
        if s.starts_with('-') && s != "-" {
            for ch in s.chars().skip(1) {
                match ch {
                    'n' => settings.number_all = true,
                    'b' => settings.number_nonblank = true,
                    's' => settings.squeeze_blank = true,
                    'E' => settings.show_ends = true,
                    'T' => settings.show_tabs = true,
                    'u' => {}
                    _ => return Err(format!("cat: invalid option -- {ch}")),
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

fn emit_line_body(
    out: &mut io::StdoutLock<'_>,
    mut body: &[u8],
    show_tabs: bool,
) -> io::Result<()> {
    if !show_tabs {
        return out.write_all(body);
    }
    while let Some(pos) = body.iter().position(|&b| b == b'\t') {
        out.write_all(&body[..pos])?;
        out.write_all(b"^I")?;
        body = &body[pos + 1..];
    }
    out.write_all(body)
}

fn cat_lines(
    reader: &mut dyn BufRead,
    settings: &Settings,
    line_no: &mut usize,
    squeeze_prev_blank: &mut bool,
) -> io::Result<()> {
    let mut stdout = io::stdout().lock();
    let mut buf = Vec::new();
    loop {
        buf.clear();
        let n = reader.read_until(b'\n', &mut buf)?;
        if n == 0 {
            break;
        }
        let ends_nl = buf.last() == Some(&b'\n');
        let body = if ends_nl {
            &buf[..buf.len().saturating_sub(1)]
        } else {
            buf.as_slice()
        };
        let is_blank_line = body.is_empty();

        if settings.squeeze_blank {
            if is_blank_line {
                if *squeeze_prev_blank {
                    continue;
                }
                *squeeze_prev_blank = true;
            } else {
                *squeeze_prev_blank = false;
            }
        }

        let print_number = if settings.number_nonblank {
            !is_blank_line
        } else {
            settings.number_all
        };

        if print_number {
            *line_no += 1;
            write!(stdout, "{:6}\t", *line_no)?;
        }

        emit_line_body(&mut stdout, body, settings.show_tabs)?;
        if settings.show_ends {
            stdout.write_all(b"$")?;
        }
        if ends_nl {
            stdout.write_all(b"\n")?;
        }
    }
    Ok(())
}

/// Concatenate inputs; returns exit status (0 ok, 1 errors on stderr).
pub fn run_cat_sync(settings: &Settings, inputs: &[Input]) -> i32 {
    let mut exit = 0i32;
    let mut global_line: usize = 0;
    for input in inputs {
        let mut squeeze_prev = false;
        match input {
            Input::Stdin => {
                let mut r = BufReader::new(io::stdin());
                if let Err(e) = cat_lines(&mut r, settings, &mut global_line, &mut squeeze_prev) {
                    eprintln!("cat: stdin: {e}");
                    exit = 1;
                }
            }
            Input::Path(p) => match File::open(p) {
                Ok(f) => {
                    let mut r = BufReader::new(f);
                    if let Err(e) = cat_lines(&mut r, settings, &mut global_line, &mut squeeze_prev)
                    {
                        eprintln!("cat: {}: {e}", p.display());
                        exit = 1;
                    }
                }
                Err(e) => {
                    eprintln!("cat: {}: {e}", p.display());
                    exit = 1;
                }
            },
        }
    }
    exit
}

/// Lazy effect graph for `cat`.
pub fn cat_effect(settings: Settings, inputs: Vec<Input>) -> Effect<i32, String, ()> {
    Effect::new(move |_| Ok(run_cat_sync(&settings, &inputs)))
}
