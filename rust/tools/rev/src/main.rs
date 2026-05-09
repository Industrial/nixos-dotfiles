//! `rev` binary.

use std::process;

use id_effect::run_blocking;
use rev::{ParsedCli, VERSION, parse_args, rev_effect};

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
            print!("{}", rev::usage());
            process::exit(0);
        }
        ParsedCli::Version => {
            println!("rev (dotfiles-rev) {VERSION}");
            process::exit(0);
        }
        ParsedCli::Run { inputs } => {
            let code = match run_blocking(rev_effect(inputs), ()) {
                Ok(c) => c,
                Err(e) => {
                    eprintln!("rev: {e}");
                    1
                }
            };
            process::exit(code);
        }
    }
}
