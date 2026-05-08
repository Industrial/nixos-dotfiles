//! `cat` binary.

use std::process;

use cat::{ParsedCli, VERSION, cat_effect, parse_args};
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
            print!("{}", cat::usage());
            process::exit(0);
        }
        ParsedCli::Version => {
            println!("cat (dotfiles-cat) {VERSION}");
            process::exit(0);
        }
        ParsedCli::Run { settings, inputs } => {
            let code = match run_blocking(cat_effect(settings, inputs), ()) {
                Ok(c) => c,
                Err(e) => {
                    eprintln!("cat: {e}");
                    1
                }
            };
            process::exit(code);
        }
    }
}
