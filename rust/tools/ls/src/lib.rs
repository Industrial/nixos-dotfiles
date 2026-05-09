//! `ls` — list directory contents (GNU coreutils parity goal, `id_effect` boundary).
//!
//! Tests follow `rust/tools/TESTING.md` (BDD-style names, module trees, rstest).

pub mod args;
pub mod format;
pub mod run;

pub use args::{Settings, parse_args, parse_args_from, usage};

use std::io;
use std::path::PathBuf;

use id_effect::Effect;

pub const VERSION: &str = "0.1.0";

#[derive(Debug, Clone)]
pub enum ParsedCli {
    Help,
    Version,
    Run {
        settings: Settings,
        paths: Vec<PathBuf>,
    },
}

/// Synchronous listing using process stdout/stderr.
pub fn run_ls_sync(settings: &Settings, paths: &[PathBuf]) -> i32 {
    let stdout = io::stdout();
    let stderr = io::stderr();
    let mut out = stdout.lock();
    let mut err = stderr.lock();
    run::run_ls_with_io(settings, paths, &mut out, &mut err)
}

pub fn ls_effect(settings: Settings, paths: Vec<PathBuf>) -> Effect<i32, String, ()> {
    Effect::new(move |_| Ok(run_ls_sync(&settings, &paths)))
}
