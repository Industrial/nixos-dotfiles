//! `sort` — sort lines of text files.

use std::cmp::Ordering;
use std::env;
use std::ffi::OsString;
use std::fs::File;
use std::io::{self, BufRead, BufReader, Write};
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
    pub reverse: bool,
    pub unique: bool,
    pub numeric: bool,
    pub ignore_case: bool,
    /// Field delimiter for `-k` / splitting (`None` = runs of whitespace).
    pub delimiter: Option<char>,
    /// 1-based field index to use as sort key (`None` = whole line).
    pub key_field: Option<usize>,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            reverse: false,
            unique: false,
            numeric: false,
            ignore_case: false,
            delimiter: None,
            key_field: None,
        }
    }
}

#[derive(Debug, Clone)]
pub enum Input {
    Stdin,
    Path(PathBuf),
}

pub fn usage() -> &'static str {
    "Usage: sort [OPTION]... [FILE]...\n\n\
Write sorted concatenation of FILE(s) to standard output.\n\n\
GNU/POSIX subset:\n\
  -f, --ignore-case    fold lower case to upper case\n\
  -n, --numeric-sort   compare according to string numerical value\n\
  -r, --reverse        reverse the result of comparisons\n\
  -u, --unique         output only the first of an equal run\n\
  -t, --field-separator=C  use C instead of non-whitespace to whitespace transition\n\
  -k, --key=POS        sort via key starting at POS (1-based field)\n\
      --help           display this help and exit\n\
      --version        output version information and exit\n"
}

fn parse_key_field(s: &str) -> Result<usize, String> {
    let n: usize = s.parse().map_err(|_| format!("sort: invalid key {s:?}"))?;
    if n == 0 {
        return Err("sort: key position 0 is undefined".into());
    }
    Ok(n)
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
                "--ignore-case" => settings.ignore_case = true,
                "--numeric-sort" => settings.numeric = true,
                "--reverse" => settings.reverse = true,
                "--unique" => settings.unique = true,
                "--field-separator" => {
                    let v = it.next().ok_or_else(|| {
                        "sort: option requires an argument --field-separator".to_string()
                    })?;
                    let vs = v.to_string_lossy();
                    let mut itc = vs.chars();
                    let c = itc
                        .next()
                        .ok_or_else(|| "sort: empty separator".to_string())?;
                    if itc.next().is_some() {
                        return Err("sort: separator must be a single character".into());
                    }
                    settings.delimiter = Some(c);
                }
                long if long.starts_with("--field-separator=") => {
                    let rest = &long["--field-separator=".len()..];
                    let mut itc = rest.chars();
                    let c = itc
                        .next()
                        .ok_or_else(|| "sort: empty separator".to_string())?;
                    if itc.next().is_some() {
                        return Err("sort: separator must be a single character".into());
                    }
                    settings.delimiter = Some(c);
                }
                long if long.starts_with("--key=") => {
                    let v = &long["--key=".len()..];
                    settings.key_field = Some(parse_key_field(v)?);
                }
                "--key" => {
                    let v = it
                        .next()
                        .ok_or_else(|| "sort: option requires an argument --key".to_string())?;
                    settings.key_field = Some(parse_key_field(&v.to_string_lossy())?);
                }
                _ => return Err(format!("sort: unrecognized option {s:?}")),
            }
            continue;
        }
        if s.starts_with('-') && s != "-" {
            let mut chars = s.chars().skip(1);
            while let Some(ch) = chars.next() {
                match ch {
                    'f' => settings.ignore_case = true,
                    'n' => settings.numeric = true,
                    'r' => settings.reverse = true,
                    'u' => settings.unique = true,
                    't' => {
                        let sep = chars.next().ok_or_else(|| {
                            "sort: option requires an argument for -t".to_string()
                        })?;
                        settings.delimiter = Some(sep);
                        break;
                    }
                    'k' => {
                        let rest: String = chars.collect();
                        let v = if rest.is_empty() {
                            it.next()
                                .ok_or_else(|| {
                                    "sort: option requires an argument for -k".to_string()
                                })?
                                .to_string_lossy()
                                .into_owned()
                        } else {
                            rest
                        };
                        settings.key_field = Some(parse_key_field(&v)?);
                        break;
                    }
                    _ => return Err(format!("sort: invalid option -- {ch}")),
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

fn split_fields<'a>(line: &'a str, delimiter: Option<char>) -> Vec<&'a str> {
    match delimiter {
        Some(d) => line.split(d).collect(),
        None => line
            .split(char::is_whitespace)
            .filter(|s| !s.is_empty())
            .collect(),
    }
}

fn sort_key<'a>(line: &'a str, settings: &Settings) -> &'a str {
    let Some(k) = settings.key_field else {
        return line;
    };
    let fields = split_fields(line, settings.delimiter);
    fields.get(k - 1).copied().unwrap_or("")
}

fn cmp_lines(a: &str, b: &str, settings: &Settings) -> Ordering {
    let ka = sort_key(a, settings);
    let kb = sort_key(b, settings);
    let ord = if settings.numeric {
        let na = ka.trim().parse::<f64>().ok();
        let nb = kb.trim().parse::<f64>().ok();
        match (na, nb) {
            (Some(x), Some(y)) => x.partial_cmp(&y).unwrap_or(Ordering::Equal),
            (Some(_), None) => Ordering::Less,
            (None, Some(_)) => Ordering::Greater,
            (None, None) => {
                if settings.ignore_case {
                    ka.to_ascii_lowercase().cmp(&kb.to_ascii_lowercase())
                } else {
                    ka.cmp(kb)
                }
            }
        }
    } else if settings.ignore_case {
        ka.to_ascii_lowercase().cmp(&kb.to_ascii_lowercase())
    } else {
        ka.cmp(kb)
    };
    if settings.reverse { ord.reverse() } else { ord }
}

/// Read lines (including trailing partial line), sort, print.
pub fn run_sort_sync(settings: &Settings, inputs: &[Input]) -> i32 {
    let mut lines: Vec<String> = Vec::new();
    let mut exit = 0i32;

    for input in inputs {
        let mut reader: Box<dyn BufRead> = match input {
            Input::Stdin => Box::new(BufReader::new(io::stdin())),
            Input::Path(p) => match File::open(p) {
                Ok(f) => Box::new(BufReader::new(f)),
                Err(e) => {
                    eprintln!("sort: {}: {e}", p.display());
                    exit = 1;
                    continue;
                }
            },
        };
        let mut buf = String::new();
        loop {
            buf.clear();
            match reader.read_line(&mut buf) {
                Ok(0) => break,
                Ok(_) => {
                    let s = buf.trim_end_matches(['\r', '\n']).to_string();
                    lines.push(s);
                }
                Err(e) => {
                    eprintln!("sort: read error: {e}");
                    exit = 1;
                    break;
                }
            }
        }
    }

    lines.sort_by(|a, b| cmp_lines(a, b, settings));

    if settings.unique {
        lines.dedup_by(|a, b| cmp_lines(a, b, settings) == Ordering::Equal);
    }

    let mut out = io::stdout().lock();
    for line in &lines {
        if writeln!(out, "{line}").is_err() {
            eprintln!("sort: write error");
            return 1;
        }
    }
    exit
}

pub fn sort_effect(settings: Settings, inputs: Vec<Input>) -> Effect<i32, String, ()> {
    Effect::new(move |_| Ok(run_sort_sync(&settings, &inputs)))
}
