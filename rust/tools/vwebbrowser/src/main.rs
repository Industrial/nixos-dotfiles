//! Entry point: the command line, then the GTK edge. The program itself is
//! `src/app.vlt`; `gtk_edge::run` hosts it.

use std::process::ExitCode;

use vwebbrowser::app::{self, Start};

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    match app::start_of(&args) {
        Ok(Start::Help) => {
            println!("{}", app::USAGE);
            ExitCode::SUCCESS
        }
        Ok(Start::Browse(url)) => vwebbrowser::gtk_edge::run(url),
        // Usage errors exit 2, before anything starts.
        Err(e) => {
            eprintln!("vwebbrowser: {e}");
            ExitCode::from(2)
        }
    }
}
