//! `wc` binary — thin CLI over [`wc::wc_effect`] and [`id_effect::run_blocking`].

use std::process;

use id_effect::run_blocking;
use wc::{ParsedCli, VERSION, parse_args, wc_effect};

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
            print!("{}", wc::usage());
            process::exit(0);
        }
        ParsedCli::Version => {
            println!("wc (dotfiles-wc) {VERSION}");
            process::exit(0);
        }
        ParsedCli::Run { settings, inputs } => {
            let code = match run_blocking(wc_effect(settings, inputs), ()) {
                Ok(c) => c,
                Err(e) => {
                    eprintln!("wc: {e}");
                    1
                }
            };
            process::exit(code);
        }
    }
}
