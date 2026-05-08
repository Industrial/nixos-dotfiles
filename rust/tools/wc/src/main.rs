//! `wc` — line, word, byte, and character counts (GNU-compatible subset).
//!
//! Word/UTF-8 handling follows the approach used in uutils coreutils `uu_wc`
//! (MIT/Apache-2.0); see repository license headers in upstream.

use std::cmp::{self, max};
use std::env;
use std::ffi::{OsStr, OsString};
use std::fs::File;
use std::io::{self, BufReader, Read, Write};
use std::path::{Path, PathBuf};
use std::process;

#[cfg(unix)]
use std::os::unix::ffi::OsStrExt;

use unicode_width::UnicodeWidthChar;

const VERSION: &str = "0.1.0";
const MIN_WIDTH: usize = 7;

#[derive(Debug, Clone, Copy, Default)]
struct WordCount {
    bytes: usize,
    chars: usize,
    lines: usize,
    words: usize,
    max_line_length: usize,
}

impl WordCount {
    fn saturating_add(self, other: Self) -> Self {
        Self {
            bytes: self.bytes.saturating_add(other.bytes),
            chars: self.chars.saturating_add(other.chars),
            lines: self.lines.saturating_add(other.lines),
            words: self.words.saturating_add(other.words),
            max_line_length: max(self.max_line_length, other.max_line_length),
        }
    }
}

#[derive(Debug, Clone)]
struct Settings {
    show_lines: bool,
    show_words: bool,
    show_chars: bool,
    show_bytes: bool,
    show_max_line_length: bool,
    debug: bool,
    files0_from: Option<OsString>,
    total_when: TotalWhen,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            show_lines: true,
            show_words: true,
            show_chars: false,
            show_bytes: true,
            show_max_line_length: false,
            debug: false,
            files0_from: None,
            total_when: TotalWhen::Auto,
        }
    }
}

impl Settings {
    fn number_enabled(&self) -> u32 {
        [
            self.show_lines,
            self.show_words,
            self.show_chars,
            self.show_bytes,
            self.show_max_line_length,
        ]
        .into_iter()
        .map(|b| u32::from(b))
        .sum()
    }

    fn finalize(mut self) -> Self {
        if self.number_enabled() == 0 {
            self.show_lines = true;
            self.show_words = true;
            self.show_bytes = true;
            self.show_chars = false;
        }
        self
    }
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
enum TotalWhen {
    #[default]
    Auto,
    Always,
    Only,
    Never,
}

impl TotalWhen {
    fn parse(s: &str) -> Option<Self> {
        match s {
            "auto" => Some(Self::Auto),
            "always" => Some(Self::Always),
            "only" => Some(Self::Only),
            "never" => Some(Self::Never),
            _ => None,
        }
    }

    fn is_total_row_visible(self, num_inputs: usize) -> bool {
        match self {
            Self::Auto => num_inputs > 1,
            Self::Always | Self::Only => true,
            Self::Never => false,
        }
    }
}

#[derive(Debug, Clone)]
enum Input {
    Stdin(StdinKind),
    Path(PathBuf),
}

#[derive(Debug, Clone, Copy)]
enum StdinKind {
    Implicit,
    Explicit,
}

fn is_posixly_correct() -> bool {
    env::var_os("POSIXLY_CORRECT").is_some()
}

fn process_text(
    total: &mut WordCount,
    text: &str,
    current_len: &mut usize,
    in_word: &mut bool,
    posix: bool,
    settings: &Settings,
) {
    for ch in text.chars() {
        if settings.show_words {
            let is_space = if posix {
                matches!(ch, '\t'..='\r' | ' ')
            } else {
                ch.is_whitespace()
            };

            if is_space {
                *in_word = false;
            } else if !*in_word {
                *in_word = true;
                total.words += 1;
            }
        }
        if settings.show_max_line_length {
            match ch {
                '\n' | '\r' | '\x0c' => {
                    total.max_line_length = max(*current_len, total.max_line_length);
                    *current_len = 0;
                }
                '\t' => {
                    *current_len -= *current_len % 8;
                    *current_len += 8;
                }
                _ => {
                    *current_len += ch.width().unwrap_or(0);
                }
            }
        }
        if settings.show_lines && ch == '\n' {
            total.lines += 1;
        }
        if settings.show_chars {
            total.chars += 1;
        }
    }
    total.bytes += text.len();
    total.max_line_length = max(*current_len, total.max_line_length);
}

fn handle_invalid_bytes(bytes: &[u8], total: &mut WordCount, in_word: &mut bool) {
    total.bytes += bytes.len();
    if !*in_word {
        *in_word = true;
        total.words += 1;
    }
}

fn count_buffer(data: &[u8], settings: &Settings, posix: bool) -> WordCount {
    let mut total = WordCount::default();

    // Fast path: bytes only.
    if settings.show_bytes
        && !settings.show_lines
        && !settings.show_words
        && !settings.show_chars
        && !settings.show_max_line_length
    {
        total.bytes = data.len();
        return total;
    }

    // Fast path: lines only (count newlines).
    if settings.show_lines
        && !settings.show_words
        && !settings.show_chars
        && !settings.show_bytes
        && !settings.show_max_line_length
    {
        total.lines = data.iter().filter(|&&b| b == b'\n').count();
        return total;
    }

    let mut pos = 0usize;
    let mut current_len = 0usize;
    let mut in_word = false;

    while pos < data.len() {
        match std::str::from_utf8(&data[pos..]) {
            Ok(s) => {
                process_text(
                    &mut total,
                    s,
                    &mut current_len,
                    &mut in_word,
                    posix,
                    settings,
                );
                break;
            }
            Err(e) => {
                let valid = e.valid_up_to();
                if valid > 0 {
                    let s = unsafe { std::str::from_utf8_unchecked(&data[pos..pos + valid]) };
                    process_text(
                        &mut total,
                        s,
                        &mut current_len,
                        &mut in_word,
                        posix,
                        settings,
                    );
                    pos += valid;
                }
                if pos >= data.len() {
                    break;
                }
                let err = std::str::from_utf8(&data[pos..]).unwrap_err();
                if let Some(len) = err.error_len() {
                    handle_invalid_bytes(&data[pos..pos + len], &mut total, &mut in_word);
                    pos += len;
                } else {
                    // Incomplete sequence at end of buffer: treat one byte as invalid.
                    handle_invalid_bytes(&data[pos..pos + 1], &mut total, &mut in_word);
                    pos += 1;
                }
            }
        }
    }

    total
}

fn count_reader<R: Read>(mut reader: R, settings: &Settings, posix: bool) -> io::Result<WordCount> {
    let mut buf = Vec::new();
    reader.read_to_end(&mut buf)?;
    Ok(count_buffer(&buf, settings, posix))
}

fn print_stats_compact(settings: &Settings, result: &WordCount) -> io::Result<()> {
    let mut stdout = io::stdout().lock();
    let cols = [
        (settings.show_lines, result.lines),
        (settings.show_words, result.words),
        (settings.show_chars, result.chars),
        (settings.show_bytes, result.bytes),
        (settings.show_max_line_length, result.max_line_length),
    ];
    let mut parts = Vec::new();
    for (_, num) in cols.iter().filter(|(show, _)| *show) {
        parts.push(format!("{num}"));
    }
    write!(stdout, "{}", parts.join(" "))?;
    writeln!(stdout)?;
    Ok(())
}

fn print_stats(
    settings: &Settings,
    result: &WordCount,
    title: Option<&OsStr>,
    number_width: usize,
) -> io::Result<()> {
    let mut stdout = io::stdout().lock();
    let cols = [
        (settings.show_lines, result.lines),
        (settings.show_words, result.words),
        (settings.show_chars, result.chars),
        (settings.show_bytes, result.bytes),
        (settings.show_max_line_length, result.max_line_length),
    ];

    let mut space = "";
    let width = number_width;
    for (_show, num) in cols.iter().filter(|(show, _)| *show) {
        write!(stdout, "{space}{num:>width$}", width = width)?;
        space = " ";
    }

    if let Some(title) = title {
        write!(stdout, "{space}")?;
        #[cfg(unix)]
        {
            use std::os::unix::ffi::OsStrExt;
            stdout.write_all(title.as_bytes())?;
        }
        #[cfg(not(unix))]
        {
            write!(stdout, "{}", title.to_string_lossy())?;
        }
    }
    writeln!(stdout)?;
    Ok(())
}

fn digit_width(n: usize) -> usize {
    if n == 0 { 1 } else { n.ilog10() as usize + 1 }
}

/// Maximum decimal width of any single counter value that will be printed.
fn max_digit_all_cells(counts: &[WordCount], sum: &WordCount, settings: &Settings) -> usize {
    let mut w = 1usize;
    for wc in counts.iter().chain(std::iter::once(sum)) {
        if settings.show_lines {
            w = cmp::max(w, digit_width(wc.lines));
        }
        if settings.show_words {
            w = cmp::max(w, digit_width(wc.words));
        }
        if settings.show_chars {
            w = cmp::max(w, digit_width(wc.chars));
        }
        if settings.show_bytes {
            w = cmp::max(w, digit_width(wc.bytes));
        }
        if settings.show_max_line_length {
            w = cmp::max(w, digit_width(wc.max_line_length));
        }
    }
    w
}

/// GNU-style field width (see uutils `compute_number_width` / coreutils): uses summed file sizes
/// when possible, and never prints narrower than the widest number.
fn field_width(
    inputs: &[Input],
    counts: &[WordCount],
    sum: &WordCount,
    settings: &Settings,
    stdin_implicit_only: bool,
) -> usize {
    let ncols = settings.number_enabled();

    if stdin_implicit_only && ncols == 1 {
        return max_digit_all_cells(counts, sum, settings);
    }
    if stdin_implicit_only && ncols > 1 {
        return cmp::max(MIN_WIDTH, max_digit_all_cells(counts, sum, settings));
    }

    if ncols == 1 && inputs.len() == 1 {
        return max_digit_all_cells(counts, sum, settings);
    }

    let mut min_w = 1usize;
    let mut size_sum: u64 = 0;

    for input in inputs {
        match input {
            Input::Stdin(_) => min_w = cmp::max(min_w, MIN_WIDTH),
            Input::Path(p) if p.as_os_str() == "-" => min_w = cmp::max(min_w, MIN_WIDTH),
            Input::Path(p) => {
                if let Ok(m) = std::fs::metadata(p) {
                    if m.is_file() {
                        size_sum = size_sum.saturating_add(m.len());
                    } else {
                        min_w = cmp::max(min_w, MIN_WIDTH);
                    }
                }
            }
        }
    }

    let mut w = if size_sum == 0 {
        min_w
    } else {
        cmp::max((1 + size_sum.ilog10()) as usize, min_w)
    };
    w = cmp::max(w, max_digit_all_cells(counts, sum, settings));
    w
}

fn read_files0_list(path: &Path) -> io::Result<Vec<PathBuf>> {
    let mut f = File::open(path)?;
    let mut buf = Vec::new();
    f.read_to_end(&mut buf)?;
    parse_files0_buffer(&buf)
}

fn usage() -> &'static str {
    "Usage: wc [OPTION]... [FILE]...\n  or:  wc [OPTION]... --files0-from=F\n\n\
Print newline, word, and byte counts for each FILE; with more than one FILE or when\n\
F is -, also print a total line. With no FILE, or when FILE is -, read standard input.\n\n\
GNU-compatible options:\n\
  -c, --bytes            print the byte counts\n\
  -m, --chars            print the character counts\n\
  -l, --lines            print the newline counts\n\
  -L, --max-line-length  print the maximum display width\n\
  -w, --words            print the number of words\n\
      --files0-from=F    read input from NUL-terminated names in file F\n\
      --total=WHEN       when to print a total line: auto, always, only, never\n\
      --help             display this help and exit\n\
      --version          output version information and exit\n"
}

fn parse_args() -> Result<(Settings, Vec<Input>), String> {
    let mut args = env::args_os().peekable();
    let _exe = args.next();

    let mut settings = Settings {
        show_lines: false,
        show_words: false,
        show_chars: false,
        show_bytes: false,
        show_max_line_length: false,
        debug: false,
        files0_from: None,
        total_when: TotalWhen::Auto,
    };

    let mut files: Vec<Input> = Vec::new();

    while let Some(arg) = args.next() {
        let arg_os = arg.as_os_str();
        if arg_os == "-" {
            files.push(Input::Path(PathBuf::from("-")));
            continue;
        }

        let s = arg.to_string_lossy();
        if s == "--" {
            files.extend(args.map(|p| Input::Path(PathBuf::from(p))));
            break;
        }

        if s.starts_with("--") {
            match s.as_ref() {
                "--help" => {
                    print!("{}", usage());
                    process::exit(0);
                }
                "--version" => {
                    println!("wc (dotfiles-wc) {VERSION}");
                    process::exit(0);
                }
                "--bytes" => settings.show_bytes = true,
                "--chars" => settings.show_chars = true,
                "--lines" => settings.show_lines = true,
                "--words" => settings.show_words = true,
                "--max-line-length" => settings.show_max_line_length = true,
                "--debug" => settings.debug = true,
                long if long.starts_with("--files0-from=") => {
                    let v = &long["--files0-from=".len()..];
                    settings.files0_from = Some(OsString::from(v));
                }
                long if long.starts_with("--total=") => {
                    let v = &long["--total=".len()..];
                    settings.total_when = TotalWhen::parse(v)
                        .ok_or_else(|| format!("wc: invalid --total argument {v:?}"))?;
                }
                _ => return Err(format!("wc: unrecognized option {s:?}")),
            }
            continue;
        }

        if s.starts_with('-') && s != "-" {
            for ch in s.chars().skip(1) {
                match ch {
                    'c' => settings.show_bytes = true,
                    'm' => settings.show_chars = true,
                    'l' => settings.show_lines = true,
                    'w' => settings.show_words = true,
                    'L' => settings.show_max_line_length = true,
                    _ => return Err(format!("wc: invalid option -- {ch}")),
                }
            }
            continue;
        }

        files.push(Input::Path(PathBuf::from(arg)));
    }

    if settings.files0_from.is_some() && !files.is_empty() {
        return Err(
            "wc: extra operand when using --files0-from\nTry 'wc --help' for more information."
                .into(),
        );
    }

    let settings = settings.finalize();

    let inputs = if let Some(ref f0) = settings.files0_from {
        let paths = if f0 == "-" {
            let stdin = io::stdin();
            let mut locked = stdin.lock();
            let mut buf = Vec::new();
            locked.read_to_end(&mut buf).map_err(|e| e.to_string())?;
            parse_files0_buffer(&buf).map_err(|e| e.to_string())?
        } else {
            read_files0_list(Path::new(f0)).map_err(|e| e.to_string())?
        };
        paths
            .into_iter()
            .map(|p| {
                if p.as_os_str() == "-" {
                    Input::Stdin(StdinKind::Explicit)
                } else {
                    Input::Path(p)
                }
            })
            .collect()
    } else if files.is_empty() {
        vec![Input::Stdin(StdinKind::Implicit)]
    } else {
        files
    };

    Ok((settings, inputs))
}

fn parse_files0_buffer(buf: &[u8]) -> io::Result<Vec<PathBuf>> {
    if buf.is_empty() {
        return Ok(Vec::new());
    }
    let mut out = Vec::new();
    for chunk in buf.split(|&b| b == 0) {
        if chunk.is_empty() {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "wc: zero-length file name in --files0-from list",
            ));
        }
        #[cfg(unix)]
        {
            out.push(PathBuf::from(OsStr::from_bytes(chunk)));
        }
        #[cfg(not(unix))]
        {
            out.push(PathBuf::from(String::from_utf8_lossy(chunk).into_owned()));
        }
    }
    Ok(out)
}

fn run() -> i32 {
    let (settings, inputs) = match parse_args() {
        Ok(x) => x,
        Err(e) => {
            eprintln!("{e}");
            return 1;
        }
    };

    if settings.debug {
        let _ = writeln!(io::stderr(), "wc (dotfiles-wc): debug: SIMD path not used");
    }

    let posix = is_posixly_correct();
    let mut exit = 0i32;

    let stdin_implicit_only = matches!(inputs.as_slice(), [Input::Stdin(StdinKind::Implicit)]);

    let mut results: Vec<(WordCount, Option<PathBuf>)> = Vec::new();

    for input in &inputs {
        let (wc, path) = match input {
            Input::Stdin(_) => match count_reader(io::stdin().lock(), &settings, posix) {
                Ok(wc) => (wc, None),
                Err(e) => {
                    eprintln!("wc: stdin: {e}");
                    exit = 1;
                    continue;
                }
            },
            Input::Path(p) if p.as_os_str() == "-" => {
                match count_reader(io::stdin().lock(), &settings, posix) {
                    Ok(wc) => (wc, Some(PathBuf::from("-"))),
                    Err(e) => {
                        eprintln!("wc: stdin: {e}");
                        exit = 1;
                        continue;
                    }
                }
            }
            Input::Path(p) => match File::open(p) {
                Ok(f) => match count_reader(BufReader::new(f), &settings, posix) {
                    Ok(wc) => (wc, Some(p.clone())),
                    Err(e) => {
                        eprintln!("wc: {}: {e}", p.display());
                        exit = 1;
                        continue;
                    }
                },
                Err(e) => {
                    eprintln!("wc: {}: {e}", p.display());
                    exit = 1;
                    continue;
                }
            },
        };
        results.push((wc, path));
    }

    let counts: Vec<WordCount> = results.iter().map(|(w, _)| *w).collect();
    let sum_counts = counts
        .iter()
        .copied()
        .fold(WordCount::default(), |a, b| a.saturating_add(b));

    let number_width = field_width(
        &inputs,
        &counts,
        &sum_counts,
        &settings,
        stdin_implicit_only,
    );

    let show_stats = settings.total_when != TotalWhen::Only;

    if show_stats {
        for (wc, path) in &results {
            let title: Option<&OsStr> = match path {
                None if stdin_implicit_only => None,
                None => Some(OsStr::new("-")),
                Some(p) => Some(p.as_os_str()),
            };
            if let Err(e) = print_stats(&settings, wc, title, number_width) {
                eprintln!("wc: write error: {e}");
                return 1;
            }
        }
    }

    if settings.total_when.is_total_row_visible(inputs.len()) {
        let total_title = if settings.total_when == TotalWhen::Only {
            None
        } else {
            Some(OsStr::new("total"))
        };
        let print_err = if settings.total_when == TotalWhen::Only {
            print_stats_compact(&settings, &sum_counts)
        } else {
            print_stats(&settings, &sum_counts, total_title, number_width)
        };
        if let Err(e) = print_err {
            eprintln!("wc: write error: {e}");
            return 1;
        }
    }

    exit
}

fn main() {
    let code = run();
    process::exit(code);
}
