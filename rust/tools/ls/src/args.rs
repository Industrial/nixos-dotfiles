//! GNU-style CLI parsing for `ls`.

use std::ffi::OsString;
use std::path::PathBuf;

use crate::ParsedCli;

/// Runtime options mirroring GNU `ls` (extended incrementally toward full parity).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Settings {
    /// `-a` / `--all`
    pub all: bool,
    /// `-A` / `--almost-all`
    pub almost_all: bool,
    /// `-l`
    pub long: bool,
    /// `-1`
    pub one_per_line: bool,
    /// `-d` / `--directory`
    pub directory: bool,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            all: false,
            almost_all: false,
            long: false,
            one_per_line: false,
            directory: false,
        }
    }
}

/// GNU-style usage text (subset; expanded as flags are implemented).
pub fn usage() -> &'static str {
    "Usage: ls [OPTION]... [FILE]...\n\n\
List information about the FILEs (the current directory by default).\n\n\
Mandatory arguments to long options are mandatory for short options too.\n\
  -a, --all                  do not ignore entries starting with .\n\
  -A, --almost-all           do not list implied . and ..\n\
  -d, --directory            list directories themselves, not their contents\n\
  -l                         use a long listing format\n\
  -1                         list one file per line\n\
      --help                 display this help and exit\n\
      --version              output version information and exit\n"
}

/// Parse `argv` including `argv[0]` (program name), like [`std::env::args_os`].
pub fn parse_args_from<I>(args_os: I) -> Result<ParsedCli, String>
where
    I: IntoIterator<Item = OsString>,
{
    let mut it = args_os.into_iter().peekable();
    let _argv0 = it.next();
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
                "--almost-all" => settings.almost_all = true,
                "--directory" => settings.directory = true,
                _ => return Err(format!("ls: unrecognized option {s:?}")),
            }
            continue;
        }
        if s.starts_with('-') && s != "-" {
            for ch in s.chars().skip(1) {
                match ch {
                    'a' => settings.all = true,
                    'A' => settings.almost_all = true,
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

pub fn parse_args() -> Result<ParsedCli, String> {
    parse_args_from(std::env::args_os())
}

#[cfg(test)]
mod tests {
    use super::*;
    use rstest::rstest;
    use std::ffi::OsStr;

    fn parse<I, S>(args: I) -> Result<ParsedCli, String>
    where
        I: IntoIterator<Item = S>,
        S: AsRef<OsStr>,
    {
        let owned: Vec<OsString> = std::iter::once(OsString::from("ls"))
            .chain(args.into_iter().map(|s| s.as_ref().to_os_string()))
            .collect();
        parse_args_from(owned)
    }

    mod parse_args_from {
        use super::*;

        mod with_help_and_version {
            use super::*;

            #[test]
            fn returns_help_when_dash_dash_help() {
                assert!(matches!(
                    parse(["--help"]).expect("parse"),
                    ParsedCli::Help
                ));
            }

            #[test]
            fn returns_version_when_dash_dash_version() {
                assert!(matches!(
                    parse(["--version"]).expect("parse"),
                    ParsedCli::Version
                ));
            }
        }

        mod with_defaults {
            use super::*;

            #[test]
            fn uses_dot_when_no_paths() {
                let ParsedCli::Run { paths, .. } = parse([]).expect("parse") else {
                    panic!("expected Run");
                };
                assert_eq!(paths, vec![PathBuf::from(".")]);
            }
        }

        mod with_flags {
            use super::*;

            #[rstest]
            #[case::short_a(&["-a"], true, false)]
            #[case::short_cap_a(&["-A"], false, true)]
            #[case::long_all(&["--all"], true, false)]
            #[case::long_almost(&["--almost-all"], false, true)]
            fn sets_all_or_almost_all(
                #[case] argv: &[&str],
                #[case] all: bool,
                #[case] almost_all: bool,
            ) {
                let ParsedCli::Run { settings, .. } = parse(argv).expect("parse") else {
                    panic!("expected Run");
                };
                assert_eq!(settings.all, all);
                assert_eq!(settings.almost_all, almost_all);
            }

            #[test]
            fn combined_short_flags_set_multiple_bits() {
                let ParsedCli::Run { settings, .. } = parse(["-lA1"]).expect("parse") else {
                    panic!("expected Run");
                };
                assert!(settings.long);
                assert!(settings.almost_all);
                assert!(settings.one_per_line);
                assert!(!settings.all);
            }

            #[test]
            fn double_dash_stops_option_parsing() {
                let ParsedCli::Run { paths, settings } = parse(["-l", "--", "-x"]).expect("parse")
                else {
                    panic!("expected Run");
                };
                assert!(settings.long);
                assert_eq!(paths, vec![PathBuf::from("-x")]);
            }
        }

        mod with_invalid_input {
            use super::*;

            #[test]
            fn rejects_unknown_long_option() {
                let err = parse(["--nope"]).expect_err("err");
                assert!(err.contains("unrecognized option"));
            }

            #[test]
            fn rejects_unknown_short_option() {
                let err = parse(["-z"]).expect_err("err");
                assert!(err.contains("invalid option"));
            }
        }
    }
}
