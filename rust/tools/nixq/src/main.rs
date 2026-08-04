//! nixq CLI — JSON/attrpath query on id_effect.

use std::path::PathBuf;
use std::process::ExitCode;

use clap::{Parser, Subcommand};
use id_effect::failure::pretty_cause;
use id_effect::{Cause, RunError, run_with};
use id_effect_cli::exit_code_for_cause;

use nixq::caps::live_providers;
use nixq::commands::{cmd_diff, cmd_force_path, cmd_get, cmd_has_attrs, cmd_normalize, cmd_subset};
use nixq::error::{InfraError, PredicateResult};

#[derive(Parser)]
#[command(
    name = "nixq",
    about = "JSON/attrpath query: get, has-attrs, subset, force-path, normalize, diff"
)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Get value at attrpath
    Get {
        attrpath: String,
        #[arg(long, short = 'f', default_value = "-")]
        file: PathBuf,
    },
    /// Exit 0 if object has all attrs
    HasAttrs {
        attrs: Vec<String>,
        #[arg(long, short = 'f', default_value = "-")]
        file: PathBuf,
    },
    /// Exit 0 if file is a structural subset of --expected
    Subset {
        #[arg(long)]
        expected: PathBuf,
        #[arg(long, short = 'f', default_value = "-")]
        file: PathBuf,
    },
    /// Exit 0 if all attrpaths resolve
    ForcePath {
        paths: Vec<String>,
        #[arg(long, short = 'f', default_value = "-")]
        file: PathBuf,
    },
    /// Print normalized JSON
    Normalize {
        #[arg(long, short = 'f', default_value = "-")]
        file: PathBuf,
    },
    /// Print structural diff vs --right (empty if equal after normalize)
    Diff {
        #[arg(long)]
        right: PathBuf,
        #[arg(long, short = 'f', default_value = "-")]
        file: PathBuf,
    },
}

fn main() -> ExitCode {
    match Cli::parse().command {
        Commands::Get { attrpath, file } => run_value(cmd_get(file, attrpath)),
        Commands::HasAttrs { attrs, file } => run_pred(cmd_has_attrs(file, attrs)),
        Commands::Subset { expected, file } => run_pred(cmd_subset(file, expected)),
        Commands::ForcePath { paths, file } => run_pred(cmd_force_path(file, paths)),
        Commands::Normalize { file } => run_value(cmd_normalize(file)),
        Commands::Diff { right, file } => run_diff(cmd_diff(file, right)),
    }
}

fn run_value(effect: id_effect::Effect<serde_json::Value, InfraError, nixq::NixqEnv>) -> ExitCode {
    match run_with(live_providers(), effect) {
        Ok(v) => {
            println!(
                "{}",
                serde_json::to_string_pretty(&v).unwrap_or_else(|_| v.to_string())
            );
            ExitCode::SUCCESS
        }
        Err(err) => exit_from_run_error(err),
    }
}

fn run_pred(effect: id_effect::Effect<PredicateResult, InfraError, nixq::NixqEnv>) -> ExitCode {
    match run_with(live_providers(), effect) {
        Ok(PredicateResult::True) => ExitCode::SUCCESS,
        Ok(PredicateResult::False) => ExitCode::from(1),
        Err(err) => exit_from_run_error(err),
    }
}

fn run_diff(effect: id_effect::Effect<String, InfraError, nixq::NixqEnv>) -> ExitCode {
    match run_with(live_providers(), effect) {
        Ok(diff) => {
            if diff.is_empty() {
                ExitCode::SUCCESS
            } else {
                println!("{diff}");
                ExitCode::from(1)
            }
        }
        Err(err) => exit_from_run_error(err),
    }
}

fn exit_from_run_error(err: RunError<InfraError>) -> ExitCode {
    let cause = match err {
        RunError::Effect(e) => Cause::Fail(e),
        other => Cause::Fail(InfraError::Json(other.to_string())),
    };
    eprintln!("{}", pretty_cause(&cause));
    let code = exit_code_for_cause(cause);
    if code == ExitCode::SUCCESS {
        ExitCode::from(2)
    } else {
        code
    }
}
