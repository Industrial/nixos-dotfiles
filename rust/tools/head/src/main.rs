//! `head` binary.

use std::process;

use head::{ParsedCli, VERSION, head_effect, parse_args};
use id_effect::run_blocking;

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
            print!("{}", head::usage());
            process::exit(0);
        }
        ParsedCli::Version => {
            println!("head (dotfiles-head) {VERSION}");
            process::exit(0);
        }
        ParsedCli::Run { settings, inputs } => {
            let code = match run_blocking(head_effect(settings, inputs), ()) {
                Ok(c) => c,
                Err(e) => {
                    eprintln!("head: {e}");
                    1
                }
            };
            process::exit(code);
        }
    }
}
