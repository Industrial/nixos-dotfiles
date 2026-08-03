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

pub use claims::{Claim, interpret_claim};
pub use compat::{CompatCase, CompatSuite, load_compat_suite};
pub use discover::{SuiteFile, discover_suites};
pub use caps::{
    Caps, FakeStore, NixEvaluator, SnapshotStore as CapsSnapshotStore, TestClock, require_store,
};
pub use eval::{EvalBackend, EvalResult, ProcessNixEval};
pub use normalize::normalize_value;
pub use outcome::{AssayOutcome, run_case};
pub use run::{RunOptions, run_suite};
