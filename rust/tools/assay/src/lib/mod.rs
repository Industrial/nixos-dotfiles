//! Assay — Nix unit testing framework (claim algebra + isolated eval runner).

pub mod assay_suite;
pub mod batch;
pub mod caps;
pub mod claims;
pub mod compat;
pub mod diff;
pub mod discover;
pub mod eval;
pub mod force;
pub mod laws;
pub mod normalize;
pub mod optics_json;
pub mod outcome;
pub mod prop;
pub mod pool;
pub mod report;
pub mod run;
pub mod schema;
pub mod snapshot;
pub mod timeout;
pub mod verdict;

pub use claims::{Claim, build_module_eval_expr, interpret_claim};
pub use compat::{CompatCase, CompatSuite, load_compat_suite};
pub use discover::{SuiteFile, discover_suites};
pub use caps::{
    AssayEnv, ClockKey, FakeStore, FsSnapshotStoreLive, LiveClockLive, MockNixEval,
    NixEvaluatorKey, NixWorkerPoolKey, ProcessNixEvalLive, SemaphoreWorkerPoolLive,
    SnapshotStoreKey, live_providers, require_store,
};
pub use pool::{MockWorkerPool, NixWorkerPool, PoolStats, SemaphoreWorkerPool};
pub use eval::{EvalBackend, EvalResult, NixEval, ProcessNixEval};
pub use normalize::normalize_value;
pub use outcome::{AssayOutcome, run_case};
pub use report::{ReportFormat, report_outcomes_stdout};
pub use verdict::{CaseVerdict, InfraError, exit_to_outcome, outcome_to_exit};
pub use run::{RunOptions, RunSummary, SuiteReport, run_discovered, run_suite, summarize};
pub use schema::{decode_claim_json, encode_claim_json, decode_suite_cases};
pub use laws::{run_builtin_laws, run_law_by_name};
pub use id_effect::Exit;

/// Wave-0 compile gate: id_effect is linked.
#[cfg(test)]
mod coverage_tests;

#[cfg(test)]
mod branch_coverage_tests;

#[cfg(test)]
mod id_effect_dep_smoke {
    use id_effect::Exit;

    #[test]
    fn id_effect_exit_is_linked() {
        let exit: Exit<(), ()> = Exit::succeed(());
        assert!(matches!(exit, Exit::Success(())));
    }

    #[cfg(feature = "cli-exit")]
    #[test]
    fn id_effect_cli_exit_code_linked() {
        use id_effect_cli::exit_code_for_exit;
        use std::process::ExitCode;
        let code = exit_code_for_exit(Exit::<(), ()>::succeed(()));
        assert_eq!(code, ExitCode::SUCCESS);
    }
}
