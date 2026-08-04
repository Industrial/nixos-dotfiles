//! nixdrv CLI — derivation parse/project and store-path helpers.

use std::path::PathBuf;
use std::process::ExitCode;

use clap::{Parser, Subcommand};
use id_effect::failure::pretty_cause;
use id_effect::{Cause, RunError, run_with};
use id_effect_cli::exit_code_for_cause;

use nixdrv::caps::live_providers;
use nixdrv::commands::{cmd_parse, cmd_project, cmd_store_path_make_fixed, cmd_store_path_parse};
use nixdrv::error::InfraError;

#[derive(Parser)]
#[command(
    name = "nixdrv",
    about = "Derivation ATerm/JSON parse, project fields, store-path helpers"
)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Parse a .drv (ATerm) or JSON derivation file
    Parse {
        #[arg(long, short = 'f', default_value = "-")]
        file: PathBuf,
    },
    /// Project selected derivation fields to JSON
    Project {
        #[arg(long, short = 'f', default_value = "-")]
        file: PathBuf,
        #[arg(long, value_delimiter = ',')]
        fields: Vec<String>,
    },
    #[command(subcommand, name = "store-path")]
    StorePath(StorePathCommands),
}

#[derive(Subcommand)]
enum StorePathCommands {
    /// Parse a Nix store path into hash, name, and full path
    Parse { path: String },
    /// Build a fixed-output store path from a known digest
    MakeFixed {
        #[arg(long)]
        name: String,
        #[arg(long, value_parser = ["flat", "recursive"])]
        method: String,
        #[arg(long)]
        hash_algo: String,
        #[arg(long)]
        digest_hex: String,
        #[arg(long)]
        store_dir: Option<String>,
    },
}

fn main() -> ExitCode {
    match Cli::parse().command {
        Commands::Parse { file } => run_value(cmd_parse(file)),
        Commands::Project { file, fields } => run_value(cmd_project(file, fields)),
        Commands::StorePath(StorePathCommands::Parse { path }) => {
            run_value(cmd_store_path_parse(path))
        }
        Commands::StorePath(StorePathCommands::MakeFixed {
            name,
            method,
            hash_algo,
            digest_hex,
            store_dir,
        }) => run_value(cmd_store_path_make_fixed(
            name, method, hash_algo, digest_hex, store_dir,
        )),
    }
}

fn run_value(
    effect: id_effect::Effect<serde_json::Value, InfraError, nixdrv::NixdrvEnv>,
) -> ExitCode {
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
