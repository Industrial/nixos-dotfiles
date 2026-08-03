//! Run assay suites and collect `Exit` outcomes.

use std::path::Path;

use id_effect::{Cap, Effect, Exit, run_test};
use serde::Serialize;

use crate::assay_suite::load_assay_suite;
use crate::caps::{AssayEnv, SnapshotStoreKey};
use crate::claims::Claim;
use crate::compat::load_compat_suite;
use crate::discover::{SuiteFile, SuiteKind, discover_suites, suite_kind};
use crate::outcome::AssayOutcome;
use crate::timeout::interpret_claim_with_retry;
use crate::verdict::{CaseVerdict, InfraError, exit_to_outcome};

#[derive(Debug, Clone, Default)]
pub struct RunOptions {
    pub update_snapshots: bool,
    pub json_output: bool,
    /// Per-case timeout in milliseconds (`None` = no limit).
    pub case_timeout_ms: Option<u64>,
    /// Retry flaky nix eval via `retry_with_clock` (default off).
    pub retry_flaky_eval: bool,
}

#[derive(Debug, Clone)]
pub struct SuiteReport { pub outcomes: Vec<(String, Exit<CaseVerdict, InfraError>)> }

#[derive(Debug, Clone, Copy, Default, Serialize, PartialEq, Eq)]
pub struct RunSummary { pub total: usize, pub passed: usize, pub failed: usize, pub errored: usize }

pub fn run_suite(path: &Path, opts: &RunOptions) -> Effect<SuiteReport, InfraError, AssayEnv> {
    let path = path.to_path_buf(); let opts = opts.clone();
    Effect::new(move |env| run_suite_on_env(&path, &opts, env))
}

fn run_suite_on_env(path: &Path, opts: &RunOptions, env: &mut AssayEnv) -> Result<SuiteReport, InfraError> {
    if opts.update_snapshots {
        let updated = env.get::<Cap<SnapshotStoreKey>>().clone().with_update(true);
        env.insert::<Cap<SnapshotStoreKey>>(updated);
    }
    let retry = opts.retry_flaky_eval;
    let _timeout_ms = opts.case_timeout_ms;
    let kind = suite_kind(path).unwrap_or(SuiteKind::CompatJson);
    let cases = match kind {
        SuiteKind::CompatJson | SuiteKind::CompatNix => load_compat_cases(path)?,
        SuiteKind::AssayNix => load_assay_suite(path).map_err(|e| InfraError::SuiteLoad(e.to_string()))?,
    };
    let env_clone = env.clone();
    let mut outcomes = Vec::with_capacity(cases.len());
    for (name, claim) in cases {
        let case_effect = interpret_claim_with_retry(claim, retry);
        outcomes.push((name, run_test(case_effect, env_clone.clone())));
    }
    Ok(SuiteReport { outcomes })
}

fn load_compat_cases(path: &Path) -> Result<Vec<(String, Claim)>, InfraError> {
    let suite = load_compat_suite(path).map_err(|e| InfraError::SuiteLoad(e.to_string()))?;
    Ok(suite.cases.into_iter().map(|c| (c.name, Claim::Eq { left_expr: c.expr, right_expr: c.expected })).collect())
}

pub fn run_discovered(root: &Path, opts: &RunOptions) -> Effect<SuiteReport, InfraError, AssayEnv> {
    let root = root.to_path_buf(); let opts = opts.clone();
    Effect::new(move |env| {
        let mut all = Vec::new();
        for suite in discover_suites(&root).map_err(|e| InfraError::Io(e.to_string()))? {
            let prefix = suite.path.display().to_string();
            for (name, exit) in run_suite_on_env(&suite.path, &opts, env)?.outcomes {
                all.push((format!("{prefix}::{name}"), exit));
            }
        }
        Ok(SuiteReport { outcomes: all })
    })
}

pub fn summarize(report: &SuiteReport) -> RunSummary { summarize_exits(&report.outcomes) }

pub fn summarize_exits(outcomes: &[(String, Exit<CaseVerdict, InfraError>)]) -> RunSummary {
    let mut s = RunSummary { total: outcomes.len(), ..Default::default() };
    for (_, exit) in outcomes {
        match exit_to_outcome(exit.clone()) {
            AssayOutcome::Pass => s.passed += 1,
            AssayOutcome::EvalError { .. } | AssayOutcome::Recursion | AssayOutcome::Timeout | AssayOutcome::ResourceLeak => s.errored += 1,
            _ => s.failed += 1,
        }
    }
    s
}

pub fn run_suite_blocking(path: &Path, opts: &RunOptions, env: AssayEnv) -> Result<SuiteReport, InfraError> {
    id_effect::runtime::run_blocking(run_suite(path, opts), env)
}
