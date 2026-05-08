//! `ls` binary.

use std::process;

use id_effect::run_blocking;
use ls::{ParsedCli, VERSION, ls_effect, parse_args};

fn main() {
    let parsed = match parse_args() {
        Ok(p) => p,
        Err(e) => {
            eprintln!("{e}");
            process::exit(1);
        }
    };

    match parsed {
        ParsedCli::Help => {
            print!("{}", ls::usage());
            process::exit(0);
        }
        ParsedCli::Version => {
            println!("ls (dotfiles-ls) {VERSION}");
            process::exit(0);
        }
        ParsedCli::Run { settings, paths } => {
            let code = match run_blocking(ls_effect(settings, paths), ()) {
                Ok(c) => c,
                Err(e) => {
                    eprintln!("ls: {e}");
                    1
                }
            };
            process::exit(code);
        }
    }
}
