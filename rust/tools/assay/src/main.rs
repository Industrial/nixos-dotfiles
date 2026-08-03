//! Assay CLI — discover and run Nix unit test suites.

use std::path::PathBuf;
use std::process::ExitCode;

use anyhow::Context;
use clap::{Parser, Subcommand};
use serde::Serialize;

use assay::{discover_suites, run_suite, AssayOutcome, RunOptions};
use assay::run::{summarize, RunSummary};

#[derive(Parser)]
#[command(name = "assay", about = "Nix unit testing: discover and run assay suites")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Run a suite file or discover and run all suites under a directory.
    Run {
        path: PathBuf,
        #[arg(long)]
        json: bool,
        #[arg(long)]
        update_snapshots: bool,
    },
    /// List suite files under a directory tree.
    Discover { path: PathBuf },
}

#[derive(Serialize)]
struct JsonOutcome {
    name: String,
    outcome: AssayOutcome,
}

fn main() -> ExitCode {
    match run() {
        Ok(code) => code,
        Err(err) => {
            eprintln!("assay: {err:#}");
            ExitCode::from(1)
        }
    }
}

fn run() -> anyhow::Result<ExitCode> {
    let cli = Cli::parse();
    match cli.command {
        Commands::Run {
            path,
            json,
            update_snapshots,
        } => cmd_run(&path, json, update_snapshots),
        Commands::Discover { path } => cmd_discover(&path),
    }
}

fn cmd_run(path: &PathBuf, json: bool, update_snapshots: bool) -> anyhow::Result<ExitCode> {
    let opts = RunOptions {
        update_snapshots,
        json_output: json,
    };

    let outcomes = if path.is_dir() {
        run_discovered(path, &opts)?
    } else {
        run_suite(path, &opts)
    };

    let summary = summarize(&outcomes);
    if json {
        print_json(&outcomes)?;
    } else {
        print_human(&outcomes, &summary);
    }

    Ok(if summary.failed == 0 && summary.errored == 0 {
        ExitCode::from(0)
    } else {
        ExitCode::from(1)
    })
}

fn run_discovered(
    root: &PathBuf,
    opts: &RunOptions,
) -> anyhow::Result<Vec<(String, AssayOutcome)>> {
    let suites = discover_suites(root).with_context(|| format!("discover {}", root.display()))?;
    let mut outcomes = Vec::new();
    for suite in suites {
        let prefix = suite.path.display().to_string();
        for (name, outcome) in run_suite(&suite.path, opts) {
            outcomes.push((format!("{prefix}::{name}"), outcome));
        }
    }
    Ok(outcomes)
}

fn cmd_discover(path: &PathBuf) -> anyhow::Result<ExitCode> {
    let suites = discover_suites(path).with_context(|| format!("discover {}", path.display()))?;
    for suite in suites {
        println!("{} ({:?})", suite.path.display(), suite.kind);
    }
    Ok(ExitCode::from(0))
}

fn print_human(outcomes: &[(String, AssayOutcome)], summary: &RunSummary) {
    for (name, outcome) in outcomes {
        let mark = match outcome {
            AssayOutcome::Pass => "PASS",
            AssayOutcome::EvalError { .. }
            | AssayOutcome::Recursion
            | AssayOutcome::Timeout
            | AssayOutcome::ResourceLeak => "ERR",
            _ => "FAIL",
        };
        println!("{mark} {name}");
        if let AssayOutcome::Fail { diff, .. } = outcome {
            println!("  {diff}");
        }
        if let AssayOutcome::EvalError { message, .. } = outcome {
            println!("  {message}");
        }
    }
    println!(
        "\n{passed}/{total} passed, {failed} failed, {errored} errored",
        passed = summary.passed,
        total = summary.total,
        failed = summary.failed,
        errored = summary.errored,
    );
}

fn print_json(outcomes: &[(String, AssayOutcome)]) -> anyhow::Result<()> {
    let rows: Vec<JsonOutcome> = outcomes
        .iter()
        .map(|(name, outcome)| JsonOutcome {
            name: name.clone(),
            outcome: outcome.clone(),
        })
        .collect();
    println!("{}", serde_json::to_string_pretty(&rows)?);
    Ok(())
}
