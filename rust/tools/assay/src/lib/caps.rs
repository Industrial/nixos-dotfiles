//! Capability keys and providers for Assay DI 3.0 (`#[capability]`, `ProviderSpec`, `provide!`).

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::Instant;

use id_effect::runtime::ThreadSleepRuntime;
use id_effect::{Clock, LiveClock, TestClock, caps, mock_capability, provide};
use serde_json::Value;

use crate::eval::{EvalBackend, EvalResult, ProcessNixEval};
use crate::outcome::AssayOutcome;
use crate::snapshot::SnapshotStore;

/// Nix evaluation backend injected at the runner edge.
pub type NixEvaluatorKey = Arc<dyn EvalBackend + Send + Sync>;

/// Golden-file snapshot store capability.
pub type SnapshotStoreKey = SnapshotStore;

/// Injectable clock for deterministic time-dependent claims.
pub type ClockKey = Arc<dyn Clock + Send + Sync>;

/// Required capabilities for an Assay run or unit-test harness.
pub type AssayEnv = caps!(NixEvaluatorKey, SnapshotStoreKey, ClockKey);

// --- Live providers ---

/// Live Nix evaluator: wraps [`ProcessNixEval`] as `Arc<dyn EvalBackend>`.
#[derive(::id_effect::ProviderSpecDerive)]
#[provides(NixEvaluatorKey)]
pub struct ProcessNixEvalLive;

impl ProcessNixEvalLive {
    fn new() -> NixEvaluatorKey {
        Arc::new(ProcessNixEval)
    }
}

/// Filesystem-backed snapshot store rooted at `testdata/goldens/`.
#[derive(::id_effect::ProviderSpecDerive)]
#[provides(SnapshotStoreKey)]
pub struct FsSnapshotStoreLive;

impl FsSnapshotStoreLive {
    fn new() -> SnapshotStoreKey {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("testdata/goldens");
        SnapshotStore::new(root)
    }
}

/// Production clock backed by [`ThreadSleepRuntime`].
#[derive(::id_effect::ProviderSpecDerive)]
#[provides(ClockKey)]
pub struct LiveClockLive;

impl LiveClockLive {
    fn new() -> ClockKey {
        Arc::new(LiveClock::new(ThreadSleepRuntime::default()))
    }
}

/// Deterministic test clock for unit tests.
#[derive(::id_effect::ProviderSpecDerive)]
#[provides(ClockKey)]
pub struct AssayTestClockLive;

impl AssayTestClockLive {
    fn new() -> ClockKey {
        Arc::new(TestClock::new(Instant::now()))
    }
}

// --- Mock providers ---

/// In-memory Nix evaluator for claim unit tests.
#[derive(Default)]
pub struct MockNixEval {
    values: Mutex<HashMap<String, EvalResult>>,
}

impl MockNixEval {
    pub fn set(&self, expr: &str, result: EvalResult) {
        self.values
            .lock()
            .unwrap()
            .insert(expr.into(), result);
    }
}

impl EvalBackend for MockNixEval {
    fn eval_json(&self, expr: &str) -> EvalResult {
        self.values
            .lock()
            .unwrap()
            .get(expr)
            .cloned()
            .unwrap_or(EvalResult::Ok(Value::Null))
    }
}

mock_capability!(
    MockNixEvalLive,
    NixEvaluatorKey,
    "nix/mock",
    || Arc::new(MockNixEval::default()) as NixEvaluatorKey
);

mock_capability!(
    MockSnapshotStoreLive,
    SnapshotStoreKey,
    "snapshot/mock-temp",
    || {
        let dir = std::env::temp_dir().join(format!(
            "assay-mock-snap-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::create_dir_all(&dir).expect("tempdir");
        SnapshotStore::new(dir)
    }
);

/// Marker for an in-memory / fake nix store used in sandboxed module tests.
#[derive(Debug, Clone, Copy, Default, Eq, PartialEq)]
pub struct FakeStore;

impl FakeStore {
    pub fn allow_ifd(&self) -> bool {
        false
    }
}

/// Require a [`FakeStore`] for sandboxed / IFD module evaluation.
pub fn require_store(store: Option<&FakeStore>) -> Result<&FakeStore, AssayOutcome> {
    store.ok_or(AssayOutcome::EvalError {
        kind: "sandbox".into(),
        message: "IFD denied: provide FakeStore capability".into(),
        span: None,
    })
}

/// Default live provider list for `run_with` at the application edge.
pub fn live_providers() -> [id_effect::ProviderBox; 3] {
    [
        provide!(ProcessNixEvalLive),
        provide!(FsSnapshotStoreLive),
        provide!(LiveClockLive),
    ]
}

#[cfg(test)]
pub fn mock_providers() -> [id_effect::ProviderBox; 3] {
    [
        provide!(MockNixEvalLive),
        provide!(MockSnapshotStoreLive),
        provide!(AssayTestClockLive),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;
    use id_effect::{Cap, Effect, Exit, FromEnv, Needs, build_env, run_test};

    #[test]
    fn build_env_materializes_all_live_capabilities() {
        let env = build_env(live_providers()).expect("env");
        assert!(env.has::<Cap<NixEvaluatorKey>>());
        assert!(env.has::<Cap<SnapshotStoreKey>>());
        assert!(env.has::<Cap<ClockKey>>());
    }

    #[test]
    fn build_env_materializes_all_mock_capabilities() {
        let env = build_env(mock_providers()).expect("env");
        assert!(env.has::<Cap<NixEvaluatorKey>>());
        assert!(env.has::<Cap<SnapshotStoreKey>>());
        assert!(env.has::<Cap<ClockKey>>());
    }

    #[test]
    fn run_test_reads_all_caps() {
        let env = AssayEnv::from_env(build_env(mock_providers()).expect("env"));
        let effect: Effect<(bool, bool, bool), (), AssayEnv> = Effect::new(|env| {
            let _nix = Needs::<NixEvaluatorKey>::need(env);
            let _snap = Needs::<SnapshotStoreKey>::need(env);
            let _clock = Needs::<ClockKey>::need(env);
            Ok((true, true, true))
        });
        let exit = run_test(effect, env);
        assert_eq!(exit, Exit::Success((true, true, true)));
    }

    #[test]
    fn mock_nix_eval_returns_configured_values() {
        let mock = Arc::new(MockNixEval::default());
        mock.set("x", EvalResult::Ok(serde_json::json!(42)));
        assert_eq!(
            mock.eval_json("x"),
            EvalResult::Ok(serde_json::json!(42))
        );
    }

    #[test]
    fn fs_snapshot_store_live_roots_at_goldens() {
        let env = build_env([provide!(FsSnapshotStoreLive)]).expect("env");
        let store = env.get::<Cap<SnapshotStoreKey>>();
        assert!(store.root.ends_with("testdata/goldens"));
    }

    #[test]
    fn fake_store_denies_ifd_by_default() {
        assert!(!FakeStore::default().allow_ifd());
    }

    #[test]
    fn require_store_err_when_missing() {
        assert_eq!(
            require_store(None),
            Err(AssayOutcome::EvalError {
                kind: "sandbox".into(),
                message: "IFD denied: provide FakeStore capability".into(),
                span: None,
            })
        );
    }

    #[test]
    fn require_store_ok_when_present() {
        let store = FakeStore;
        assert!(require_store(Some(&store)).is_ok());
    }
}
