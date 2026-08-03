//! Assay — Nix unit testing framework (claim algebra + isolated eval runner).

pub mod assay_suite;
pub mod caps;
pub mod claims;
pub mod compat;
pub mod diff;
pub mod discover;
pub mod eval;
pub mod force;
pub mod laws;
pub mod normalize;
pub mod outcome;
pub mod prop;
pub mod run;
pub mod snapshot;
pub mod verdict;

pub use claims::{Claim, interpret_claim};
pub use compat::{CompatCase, CompatSuite, load_compat_suite};
pub use discover::{SuiteFile, discover_suites};
pub use caps::{
    AssayEnv, ClockKey, FakeStore, FsSnapshotStoreLive, LiveClockLive, MockNixEval,
    NixEvaluatorKey, ProcessNixEvalLive, SnapshotStoreKey, live_providers, require_store,
};
pub use eval::{EvalBackend, EvalResult, NixEval, ProcessNixEval};
pub use normalize::normalize_value;
pub use outcome::{AssayOutcome, run_case};
pub use verdict::{CaseVerdict, InfraError, exit_to_outcome, outcome_to_exit};
pub use run::{RunOptions, run_suite};

/// Wave-0 compile gate: id_effect is linked. Full Effectify lands in later waves.
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
