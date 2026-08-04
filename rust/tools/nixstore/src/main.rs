//! nixstore CLI — read-only path-info over db.sqlite.

use std::path::PathBuf;
use std::process::ExitCode;

use clap::{ArgAction, CommandFactory, FromArgMatches, Parser, Subcommand};
use id_effect::failure::pretty_cause;
use id_effect::{Cause, Exit, FromEnv, run_test};
use id_effect_cli::exit_code_for_cause;

use nixstore::caps::{NixstoreEnv, providers_for_store};
use nixstore::commands::{PathInfoFlags, cmd_path_info, resolve_store_root};
use nixstore::error::InfraError;

#[derive(Parser)]
#[command(
    name = "nixstore",
    about = "Read-only Nix store path-info from db.sqlite",
    // Free `-h` for nix-compatible `--human-readable`.
    disable_help_flag = true
)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Query information about store paths (nix path-info compatible)
    PathInfo {
        /// Store paths to query
        paths: Vec<String>,
        /// Emit JSON object keyed by path
        #[arg(long)]
        json: bool,
        /// Print NAR size
        #[arg(long, short = 's')]
        size: bool,
        /// Print closure size
        #[arg(long, short = 'S')]
        closure_size: bool,
        /// Human-readable sizes
        #[arg(long, short = 'h')]
        human_readable: bool,
        /// Show signatures
        #[arg(long)]
        sigs: bool,
        /// Also show referrers
        #[arg(long)]
        referrers: bool,
        /// Alternate store root (default /nix)
        #[arg(long)]
        store: Option<PathBuf>,
    },
}

fn main() -> ExitCode {
    let mut cmd = Cli::command();
    cmd = cmd.arg(
        clap::Arg::new("help")
            .long("help")
            .action(ArgAction::Help)
            .global(true)
            .help("Print help"),
    );
    let matches = cmd.get_matches();
    let cli = Cli::from_arg_matches(&matches).unwrap_or_else(|e| e.exit());
    match cli.command {
        Commands::PathInfo {
            paths,
            json,
            size,
            closure_size,
            human_readable,
            sigs,
            referrers,
            store,
        } => {
            if paths.is_empty() {
                eprintln!("nixstore path-info: at least one PATH required");
                return ExitCode::from(2);
            }
            let flags = PathInfoFlags {
                json,
                size,
                closure_size,
                human_readable,
                sigs,
                referrers,
            };
            let root = resolve_store_root(store);
            let env = NixstoreEnv::from_env(providers_for_store(&root));
            match run_test(cmd_path_info(paths, flags), env) {
                Exit::Success(v) => {
                    if let Some(text) = v.get("__text__").and_then(|t| t.as_str()) {
                        println!("{text}");
                    } else {
                        println!(
                            "{}",
                            serde_json::to_string_pretty(&v).unwrap_or_else(|_| v.to_string())
                        );
                    }
                    ExitCode::SUCCESS
                }
                Exit::Failure(cause) => exit_from_cause(cause),
            }
        }
    }
}

fn exit_from_cause(cause: Cause<InfraError>) -> ExitCode {
    eprintln!("{}", pretty_cause(&cause));
    let code = exit_code_for_cause(cause);
    if code == ExitCode::SUCCESS {
        ExitCode::from(2)
    } else {
        code
    }
}
