//! Run assay suites and collect outcomes.

use std::path::Path;

use serde::Serialize;

use crate::assay_suite::load_assay_suite;
use crate::claims::{Claim, interpret_claim};
use crate::compat::{CompatCase, load_compat_suite};
use crate::discover::{SuiteKind, suite_kind};
use crate::eval::ProcessNixEval;
use crate::outcome::{AssayOutcome, run_case};

/// Options controlling suite execution and reporting.
#[derive(Debug, Clone, Default)]
pub struct RunOptions {
    pub update_snapshots: bool,
    pub json_output: bool,
}

/// Aggregated pass / fail / error counts for a run.
#[derive(Debug, Clone, Copy, Default, Serialize, PartialEq, Eq)]
pub struct RunSummary {
    pub total: usize,
    pub passed: usize,
    pub failed: usize,
    pub errored: usize,
}

/// Run a single suite file and return per-case outcomes keyed by case name.
pub fn run_suite(path: &Path, opts: &RunOptions) -> Vec<(String, AssayOutcome)> {
    let backend = ProcessNixEval;
    let kind = suite_kind(path).unwrap_or(SuiteKind::CompatJson);

    match kind {
        SuiteKind::CompatJson | SuiteKind::CompatNix => run_compat_suite(path, &backend),
        SuiteKind::AssayNix => run_assay_nix_suite(path, &backend, opts),
    }
}

/// Summarize a list of case outcomes.
pub fn summarize(outcomes: &[(String, AssayOutcome)]) -> RunSummary {
    let mut summary = RunSummary {
        total: outcomes.len(),
        ..RunSummary::default()
    };
    for (_, outcome) in outcomes {
        match outcome {
            AssayOutcome::Pass => summary.passed += 1,
            AssayOutcome::EvalError { .. }
            | AssayOutcome::Recursion
            | AssayOutcome::Timeout
            | AssayOutcome::ResourceLeak => summary.errored += 1,
            _ => summary.failed += 1,
        }
    }
    summary
}

fn run_compat_suite(path: &Path, backend: &ProcessNixEval) -> Vec<(String, AssayOutcome)> {
    let suite = match load_compat_suite(path) {
        Ok(suite) => suite,
        Err(err) => {
            return vec![(suite_label(path), suite_load_outcome(err.to_string()))];
        }
    };

    suite
        .cases
        .into_iter()
        .map(|case| (case.name.clone(), run_compat_case(backend, &case)))
        .collect()
}

fn run_compat_case(backend: &ProcessNixEval, case: &CompatCase) -> AssayOutcome {
    let claim = Claim::Eq {
        left_expr: case.expr.clone(),
        right_expr: case.expected.clone(),
    };
    run_case(|| interpret_claim(&claim, backend))
}

fn run_assay_nix_suite(
    path: &Path,
    backend: &ProcessNixEval,
    opts: &RunOptions,
) -> Vec<(String, AssayOutcome)> {
    let _ = opts.update_snapshots;
    match load_assay_suite(path) {
        Ok(cases) => cases
            .into_iter()
            .map(|(name, claim)| (name, run_case(|| interpret_claim(&claim, backend))))
            .collect(),
        Err(err) => vec![(suite_label(path), suite_load_outcome(err.to_string()))],
    }
}

fn suite_load_outcome(message: String) -> AssayOutcome {
    AssayOutcome::EvalError {
        kind: "suite_load".into(),
        message,
        span: None,
    }
}

fn suite_label(path: &Path) -> String {
    path.file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("suite")
        .to_string()
}
