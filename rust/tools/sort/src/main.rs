//! `sort` binary.

use std::process;

use id_effect::run_blocking;
use sort::{ParsedCli, VERSION, parse_args, sort_effect};

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
            print!("{}", sort::usage());
            process::exit(0);
        }
        ParsedCli::Version => {
            println!("sort (dotfiles-sort) {VERSION}");
            process::exit(0);
        }
        ParsedCli::Run { settings, inputs } => {
            let code = match run_blocking(sort_effect(settings, inputs), ()) {
                Ok(c) => c,
                Err(e) => {
                    eprintln!("sort: {e}");
                    1
                }
            };
            process::exit(code);
        }
    }
}
