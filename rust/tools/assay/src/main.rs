//! Assay CLI — discover and run Nix unit test suites.

use std::path::PathBuf;
use std::process::ExitCode;

use anyhow::Context;
use clap::{Parser, Subcommand};
use assay::{discover_suites, report_outcomes_stdout, run_suite, AssayOutcome, ReportFormat, RunOptions};
use assay::run::summarize;

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
        /// Emit JSON report (alias for `--format json`).
        #[arg(long)]
        json: bool,
        /// Report format: human, json, or tap.
        #[arg(long, value_name = "FORMAT")]
        format: Option<String>,
        #[arg(long)]
        update_snapshots: bool,
    },
    /// List suite files under a directory tree.
    Discover { path: PathBuf },
    /// Run built-in algebraic law checks.
    Laws {
        #[arg(long, default_value_t = 0)]
        seed: u64,
        #[arg(long)]
        json: bool,
    },
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
            format,
            update_snapshots,
        } => cmd_run(&path, json, format.as_deref(), update_snapshots),
        Commands::Discover { path } => cmd_discover(&path),
        Commands::Laws { seed, json } => cmd_laws(seed, json),
    }
}

fn cmd_run(
    path: &PathBuf,
    json: bool,
    format: Option<&str>,
    update_snapshots: bool,
) -> anyhow::Result<ExitCode> {
    let report_format = resolve_format(json, format)?;
    let opts = RunOptions {
        update_snapshots,
        json_output: report_format == ReportFormat::Json,
    };

    let outcomes = if path.is_dir() {
        run_discovered(path, &opts)?
    } else {
        run_suite(path, &opts)
    };

    let summary = summarize(&outcomes);
    report_outcomes_stdout(&outcomes, report_format, &summary)
        .with_context(|| "report outcomes")?;

    Ok(if summary.failed == 0 && summary.errored == 0 {
        ExitCode::from(0)
    } else {
        ExitCode::from(1)
    })
}

fn resolve_format(json: bool, format: Option<&str>) -> anyhow::Result<ReportFormat> {
    match (json, format) {
        (true, Some(f)) => {
            let parsed = ReportFormat::parse(f)
                .ok_or_else(|| anyhow::anyhow!("unknown report format: {f}"))?;
            if parsed != ReportFormat::Json {
                anyhow::bail!("--json conflicts with --format {f}");
            }
            Ok(parsed)
        }
        (true, None) => Ok(ReportFormat::Json),
        (false, Some(f)) => ReportFormat::parse(f)
            .ok_or_else(|| anyhow::anyhow!("unknown report format: {f} (expected human, json, or tap)")),
        (false, None) => Ok(ReportFormat::Human),
    }
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


fn cmd_laws(seed: u64, json: bool) -> anyhow::Result<ExitCode> {
    let laws = assay::run_builtin_laws(seed);
    let failed = laws.iter().any(|(_, o)| *o != AssayOutcome::Pass);
    if json {
        let rows: Vec<JsonOutcome> = laws
            .into_iter()
            .map(|(name, outcome)| JsonOutcome {
                name: name.to_string(),
                outcome,
            })
            .collect();
        println!("{}", serde_json::to_string_pretty(&rows)?);
    } else {
        for (name, outcome) in laws {
            let mark = if outcome == AssayOutcome::Pass { "PASS" } else { "FAIL" };
            println!("{mark} {name}");
        }
    }
    Ok(if failed { ExitCode::from(1) } else { ExitCode::from(0) })
}

fn cmd_discover(path: &PathBuf) -> anyhow::Result<ExitCode> {
    let suites = discover_suites(path).with_context(|| format!("discover {}", path.display()))?;
    for suite in suites {
        println!("{} ({:?})", suite.path.display(), suite.kind);
    }
    Ok(ExitCode::from(0))
}

