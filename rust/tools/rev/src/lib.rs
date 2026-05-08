//! `rev` — reverse the order of **bytes** in each line (POSIX-oriented).
//!
//! Lines are delimited by `\n`. The delimiter is not reversed; a final partial line
//! without a trailing newline is reversed and written without adding a newline.

use std::env;
use std::ffi::OsString;
use std::fs::File;
use std::io::{self, BufRead, BufReader, Write};
use std::path::PathBuf;

use id_effect::Effect;

/// `--version` string.
pub const VERSION: &str = "0.1.0";

/// Parsed CLI (help/version/run).
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ParsedCli {
    Help,
    Version,
    Run { inputs: Vec<Input> },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Input {
    Stdin,
    Path(PathBuf),
}

pub fn usage() -> &'static str {
    "Usage: rev [OPTION]... [FILE]...\n\n\
Write each line of each FILE to standard output, with the order of bytes reversed.\n\
With no FILE, or when FILE is -, read standard input.\n\n\
Options:\n\
      --help       display this help and exit\n\
      --version    output version information and exit\n"
}

/// Reverse `body` (line without trailing `\n`) byte-for-byte.
#[must_use]
pub fn reverse_line_bytes(body: &[u8]) -> Vec<u8> {
    body.iter().rev().copied().collect()
}

/// Copy `reader` to `writer`, reversing bytes in each newline-delimited line.
pub fn rev_lines<R: BufRead, W: Write>(reader: R, writer: &mut W) -> io::Result<()> {
    let mut reader = reader;
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
        let rev = reverse_line_bytes(body);
        writer.write_all(&rev)?;
        if ends_nl {
            writer.write_all(b"\n")?;
        }
    }
    Ok(())
}

/// Parse argv **after** the program name (same slice as `env::args_os().skip(1)`).
pub fn parse_args_from<I>(args: I) -> Result<ParsedCli, String>
where
    I: IntoIterator<Item = OsString>,
{
    let mut it = args.into_iter().peekable();
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
                _ => return Err(format!("rev: unrecognized option {s:?}")),
            }
        } else {
            files.push(arg);
        }
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

    Ok(ParsedCli::Run { inputs })
}

pub fn parse_args() -> Result<ParsedCli, String> {
    parse_args_from(env::args_os().skip(1))
}

/// Reverse inputs; returns exit status (0 ok, 1 on any I/O or open error).
pub fn run_rev_sync(inputs: &[Input]) -> i32 {
    let mut exit = 0i32;
    let mut stdout = io::stdout().lock();

    for input in inputs {
        match input {
            Input::Stdin => {
                let stdin = io::stdin().lock();
                let reader = BufReader::new(stdin);
                if let Err(e) = rev_lines(reader, &mut stdout) {
                    eprintln!("rev: stdin: {e}");
                    exit = 1;
                }
            }
            Input::Path(p) => match File::open(p) {
                Ok(f) => {
                    let reader = BufReader::new(f);
                    if let Err(e) = rev_lines(reader, &mut stdout) {
                        eprintln!("rev: {}: {e}", p.display());
                        exit = 1;
                    }
                }
                Err(e) => {
                    eprintln!("rev: {}: {e}", p.display());
                    exit = 1;
                }
            },
        }
    }
    exit
}

/// Lazy effect graph for `rev`.
pub fn rev_effect(inputs: Vec<Input>) -> Effect<i32, String, ()> {
    Effect::new(move |_| Ok(run_rev_sync(&inputs)))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    use rstest::rstest;

    mod reverse_line_bytes {
        use super::*;

        #[test]
        fn reverses_ascii_bytes() {
            assert_eq!(reverse_line_bytes(b"hello"), b"olleh".as_slice());
        }

        #[test]
        fn empty_body_yields_empty() {
            assert!(reverse_line_bytes(b"").is_empty());
        }

        #[test]
        fn preserves_utf8_byte_sequence_when_reversed() {
            let s = "café".as_bytes();
            let rev = reverse_line_bytes(s);
            assert_eq!(rev, s.iter().rev().copied().collect::<Vec<_>>());
        }
    }

    mod rev_lines {
        use super::*;

        #[rstest]
        #[case::hello(b"hello\n", b"olleh\n")]
        #[case::single_char(b"a\n", b"a\n")]
        #[case::empty_line(b"\n", b"\n")]
        #[case::two_lines(b"ab\ncd\n", b"ba\ndc\n")]
        fn when_input_has_unix_newlines_then_output_matches(
            #[case] input: &[u8],
            #[case] expected: &[u8],
        ) {
            let mut out = Vec::new();
            rev_lines(Cursor::new(input), &mut out).unwrap();
            assert_eq!(out, expected);
        }

        #[test]
        fn when_final_line_has_no_newline_then_output_has_no_trailing_newline() {
            let mut out = Vec::new();
            rev_lines(Cursor::new(b"abc"), &mut out).unwrap();
            assert_eq!(out, b"cba");
        }

        #[test]
        fn when_input_empty_then_output_empty() {
            let mut out = Vec::new();
            rev_lines(Cursor::new(b""), &mut out).unwrap();
            assert!(out.is_empty());
        }

        #[test]
        fn when_only_newline_then_emits_single_newline() {
            let mut out = Vec::new();
            rev_lines(Cursor::new(b"\n"), &mut out).unwrap();
            assert_eq!(out, b"\n");
        }
    }

    mod parse_args_from {
        use super::*;

        #[test]
        fn returns_help_when_only_double_dash_help() {
            let p = parse_args_from([OsString::from("--help")]).unwrap();
            assert_eq!(p, ParsedCli::Help);
        }

        #[test]
        fn returns_version_when_double_dash_version() {
            let p = parse_args_from([OsString::from("--version")]).unwrap();
            assert_eq!(p, ParsedCli::Version);
        }

        #[test]
        fn rejects_unrecognized_long_option() {
            let err = parse_args_from([OsString::from("--nope")]).unwrap_err();
            assert!(err.contains("unrecognized"));
        }

        #[test]
        fn with_no_operands_uses_stdin() {
            let p = parse_args_from([]).unwrap();
            assert_eq!(
                p,
                ParsedCli::Run {
                    inputs: vec![Input::Stdin]
                }
            );
        }

        #[test]
        fn maps_dash_to_stdin() {
            let p = parse_args_from([OsString::from("-")]).unwrap();
            assert_eq!(
                p,
                ParsedCli::Run {
                    inputs: vec![Input::Stdin]
                }
            );
        }

        #[test]
        fn double_dash_passes_through_operand_starting_with_dash() {
            let p = parse_args_from([OsString::from("--"), OsString::from("-weird")]).unwrap();
            assert_eq!(
                p,
                ParsedCli::Run {
                    inputs: vec![Input::Path(PathBuf::from("-weird"))]
                }
            );
        }
    }

    mod rev_lines_from_file {
        use super::*;
        use std::io::Write;

        use tempfile::NamedTempFile;

        #[test]
        fn reads_file_and_reverses_lines() {
            let mut f = NamedTempFile::new().unwrap();
            f.write_all(b"one\ntwo\n").unwrap();
            f.flush().unwrap();

            let file = File::open(f.path()).unwrap();
            let mut out = Vec::new();
            rev_lines(BufReader::new(file), &mut out).unwrap();
            assert_eq!(out, b"eno\nowt\n");
        }
    }

    mod rev_effect {
        use super::*;
        use std::io::Write;

        use id_effect::run_blocking;
        use tempfile::NamedTempFile;

        #[test]
        fn run_blocking_on_file_input_returns_zero() {
            let mut f = NamedTempFile::new().unwrap();
            f.write_all(b"x\n").unwrap();
            f.flush().unwrap();
            let path = f.path().to_owned();
            let eff = rev_effect(vec![Input::Path(path)]);
            let code = run_blocking(eff, ()).unwrap();
            assert_eq!(code, 0);
        }
    }
}
