//! nixfetch CLI — hash / verify / fetch-url / fetch-git / store-path.

use std::path::PathBuf;
use std::process::ExitCode;

use clap::{Parser, Subcommand};
use id_effect::failure::pretty_cause;
use id_effect::{Cause, RunError, run_with};
use id_effect_cli::exit_code_for_cause;

use nixfetch::{
    InfraError, cmd_fetch_git, cmd_fetch_url, cmd_hash, cmd_store_path, cmd_verify, live_providers,
};

#[derive(Debug, Parser)]
#[command(name = "nixfetch", about = "Fixed-output fetchers: hash, verify, fetchurl/fetchgit")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Debug, Subcommand)]
enum Commands {
    /// Hash a path (flat file bytes or recursive NAR)
    Hash {
        path: PathBuf,
        #[arg(long, group = "mode")]
        flat: bool,
        #[arg(long, group = "mode")]
        recursive: bool,
    },
    /// Verify a path against an expected digest (SRI, nix32, or hex)
    Verify {
        path: PathBuf,
        #[arg(long)]
        expected: String,
        #[arg(long, group = "mode")]
        flat: bool,
        #[arg(long, group = "mode")]
        recursive: bool,
    },
    /// Download URL and flat-verify against expected hash
    FetchUrl {
        url: String,
        #[arg(long)]
        hash: String,
        #[arg(long)]
        out: Option<PathBuf>,
        #[arg(long)]
        name: Option<String>,
    },
    /// Export git rev and recursive-verify against expected hash
    FetchGit {
        url: String,
        #[arg(long)]
        rev: String,
        #[arg(long)]
        hash: String,
        #[arg(long)]
        dest: Option<PathBuf>,
        #[arg(long)]
        name: Option<String>,
    },
    /// Compute nixdrv fixed-output store path from digest + name
    StorePath {
        #[arg(long)]
        name: String,
        #[arg(long)]
        hash: String,
        #[arg(long)]
        recursive: bool,
        #[arg(long)]
        store_dir: Option<String>,
    },
}

fn ingestion_recursive(flat: bool, recursive: bool) -> Result<bool, InfraError> {
    match (flat, recursive) {
        (true, false) => Ok(false),
        (false, true) => Ok(true),
        (false, false) => Ok(false),
        (true, true) => Err(InfraError::Parse(
            "pass only one of --flat or --recursive".into(),
        )),
    }
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    match cli.command {
        Commands::Hash {
            path,
            flat,
            recursive,
        } => match ingestion_recursive(flat, recursive) {
            Ok(rec) => run_value(cmd_hash(path, rec)),
            Err(e) => exit_infra(e),
        },
        Commands::Verify {
            path,
            expected,
            flat,
            recursive,
        } => match ingestion_recursive(flat, recursive) {
            Ok(rec) => run_value(cmd_verify(path, expected, rec)),
            Err(e) => exit_infra(e),
        },
        Commands::FetchUrl {
            url,
            hash,
            out,
            name,
        } => run_value(cmd_fetch_url(url, hash, out, name)),
        Commands::FetchGit {
            url,
            rev,
            hash,
            dest,
            name,
        } => run_value(cmd_fetch_git(url, rev, hash, dest, name)),
        Commands::StorePath {
            name,
            hash,
            recursive,
            store_dir,
        } => run_value(cmd_store_path(name, hash, recursive, store_dir)),
    }
}

fn run_value(
    effect: id_effect::Effect<serde_json::Value, InfraError, nixfetch::NixfetchEnv>,
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

fn exit_infra(e: InfraError) -> ExitCode {
    eprintln!("{e}");
    ExitCode::from(2)
}

fn exit_from_run_error(err: RunError<InfraError>) -> ExitCode {
    let cause = match err {
        RunError::Effect(e) => Cause::Fail(e),
        other => Cause::Fail(InfraError::Json(other.to_string())),
    };
    eprintln!("{}", pretty_cause(&cause));
    match cause {
        Cause::Fail(InfraError::HashMismatch { .. }) => ExitCode::from(1),
        Cause::Fail(_) => ExitCode::from(2),
        other => {
            let code = exit_code_for_cause(other);
            if code == ExitCode::SUCCESS {
                ExitCode::from(2)
            } else {
                code
            }
        }
    }
}
