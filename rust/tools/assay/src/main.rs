//! Assay CLI — discover and run Nix unit test suites.

use std::path::PathBuf;
use std::process::ExitCode;

use clap::{Parser, Subcommand};
use id_effect::{Cause, Exit, run_with};
use id_effect::failure::pretty_cause;
use id_effect_cli::{cause_max_exit_byte, exit_code_for_cause};
use serde::Serialize;

use assay::caps::live_providers;
use assay::discover::discover_suites;
use assay::run::{RunOptions, run_discovered, run_suite, summarize};
use assay::verdict::{CaseVerdict, InfraError, exit_to_outcome};
use assay::{report_outcomes_stdout, AssayOutcome, ReportFormat, SuiteReport};

#[derive(Parser)]
#[command(name = "assay", about = "Nix unit testing: discover and run assay suites")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    Run {
        path: PathBuf,
        #[arg(long)]
        json: bool,
        #[arg(long, value_name = "FORMAT")]
        format: Option<String>,
        #[arg(long)]
        update_snapshots: bool,
        #[arg(long, value_name = "MS")]
        case_timeout_ms: Option<u64>,
        #[arg(long)]
        retry_flaky_eval: bool,
        /// Disable tryEval mega-batch (one nix process per claim).
        #[arg(long)]
        no_batch: bool,
    },
    Discover { path: PathBuf },
    Laws {
        #[arg(long, default_value_t = 0)]
        seed: u64,
        #[arg(long)]
        json: bool,
    },
}

#[derive(Serialize)]
struct JsonOutcome {
    name: String,
    outcome: AssayOutcome,
}

fn main() -> ExitCode {
    match Cli::parse().command {
        Commands::Run {
            path,
            json,
            format,
            update_snapshots,
            case_timeout_ms,
            retry_flaky_eval,
            no_batch,
        } => cmd_run(
            &path,
            json,
            format.as_deref(),
            update_snapshots,
            case_timeout_ms,
            retry_flaky_eval,
            !no_batch,
        ),
        Commands::Discover { path } => cmd_discover(&path),
        Commands::Laws { seed, json } => cmd_laws(seed, json),
    }
}

fn cmd_run(
    path: &PathBuf,
    json: bool,
    format: Option<&str>,
    update_snapshots: bool,
    case_timeout_ms: Option<u64>,
    retry_flaky_eval: bool,
    batch_eval: bool,
) -> ExitCode {
    let report_format = match resolve_format(json, format) {
        Ok(f) => f,
        Err(err) => {
            eprintln!("assay: {err}");
            return ExitCode::from(1);
        }
    };

    let opts = RunOptions {
        update_snapshots,
        json_output: report_format == ReportFormat::Json,
        case_timeout_ms,
        retry_flaky_eval,
        batch_eval,
    };

    let effect = if path.is_dir() {
        run_discovered(path, &opts)
    } else {
        run_suite(path, &opts)
    };

    let providers = live_providers();
    let t_run = std::time::Instant::now();
    match run_with(providers, effect) {
        Ok(report) => {
            if std::env::var_os("ASSAY_TRACE").is_some() {
                eprintln!(
                    "assay_trace: run_with {:.1}ms",
                    t_run.elapsed().as_secs_f64() * 1000.0
                );
            }
            let outcomes = legacy_outcomes(&report);
            let summary = summarize(&report);
            if let Err(err) = report_outcomes_stdout(&outcomes, report_format, &summary) {
                eprintln!("assay: {err}");
                return ExitCode::from(1);
            }
            exit_code_for_suite(&report)
        }
        Err(infra) => {
            let cause = Cause::Fail(infra);
            eprintln!("{}", pretty_cause(&cause));
            exit_code_for_cause(cause)
        }
    }
}

fn legacy_outcomes(report: &SuiteReport) -> Vec<(String, AssayOutcome)> {
    report
        .outcomes
        .iter()
        .map(|(name, exit)| (name.clone(), exit_to_outcome(exit.clone())))
        .collect()
}

fn resolve_format(json: bool, format: Option<&str>) -> Result<ReportFormat, String> {
    match (json, format) {
        (true, Some(f)) => {
            let parsed = ReportFormat::parse(f)
                .ok_or_else(|| format!("unknown report format: {f}"))?;
            if parsed != ReportFormat::Json {
                return Err(format!("--json conflicts with --format {f}"));
            }
            Ok(parsed)
        }
        (true, None) => Ok(ReportFormat::Json),
        (false, Some(f)) => ReportFormat::parse(f)
            .ok_or_else(|| format!("unknown report format: {f} (expected human, json, or tap)")),
        (false, None) => Ok(ReportFormat::Human),
    }
}

fn cmd_discover(path: &PathBuf) -> ExitCode {
    match discover_suites(path) {
        Ok(suites) => {
            for suite in suites {
                println!("{} ({:?})", suite.path.display(), suite.kind);
            }
            ExitCode::SUCCESS
        }
        Err(err) => {
            eprintln!("assay: discover {}: {err:#}", path.display());
            ExitCode::from(1)
        }
    }
}

fn cmd_laws(seed: u64, json: bool) -> ExitCode {
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
        match serde_json::to_string_pretty(&rows) {
            Ok(s) => println!("{s}"),
            Err(err) => {
                eprintln!("assay: {err}");
                return ExitCode::from(1);
            }
        }
    } else {
        for (name, outcome) in laws {
            let mark = if outcome == AssayOutcome::Pass { "PASS" } else { "FAIL" };
            println!("{mark} {name}");
        }
    }
    if failed {
        ExitCode::from(1)
    } else {
        ExitCode::SUCCESS
    }
}

fn exit_code_for_suite(report: &SuiteReport) -> ExitCode {
    let worst = report
        .outcomes
        .iter()
        .map(|(_, exit)| exit_code_byte(exit))
        .max()
        .unwrap_or(0);
    ExitCode::from(worst)
}

fn exit_code_byte(exit: &Exit<CaseVerdict, InfraError>) -> u8 {
    match exit {
        Exit::Failure(cause) => cause_max_exit_byte(cause),
        Exit::Success(CaseVerdict::Pass) => 0,
        Exit::Success(_) => 1,
    }
}
