//! Capability keys and providers for Assay DI 3.0 (`#[capability]`, `ProviderSpec`, `provide!`).

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::Instant;

use id_effect::{Clock, Effect, Never, TestClock, caps, mock_capability, provide};
use serde_json::Value;
use std::time::Duration;

use crate::eval::{EvalBackend, EvalResult, ProcessNixEval};
use crate::outcome::AssayOutcome;
use crate::pool::{MockWorkerPool, NixWorkerPool, SemaphoreWorkerPool};
use crate::snapshot::SnapshotStore;
use nixstore::{MockPathInfoStore, PathInfoStore, SqlitePathInfoStore};

/// Nix evaluation backend injected at the runner edge.
pub type NixEvaluatorKey = Arc<dyn EvalBackend + Send + Sync>;

/// Golden-file snapshot store capability.
pub type SnapshotStoreKey = SnapshotStore;

/// Injectable clock for deterministic time-dependent claims.
pub type ClockKey = Arc<dyn Clock + Send + Sync>;

/// Bounded concurrent Nix worker slots.
pub type NixWorkerPoolKey = Arc<dyn NixWorkerPool + Send + Sync>;

/// Read-only Nix store path-info (sqlite).
pub type PathInfoStoreKey = Arc<dyn PathInfoStore>;

/// Required capabilities for an Assay run or unit-test harness.
pub type AssayEnv = caps!(
    NixEvaluatorKey,
    SnapshotStoreKey,
    ClockKey,
    NixWorkerPoolKey,
    PathInfoStoreKey
);

// --- Live providers ---

/// Live Nix evaluator: wraps [`ProcessNixEval`] as `Arc<dyn EvalBackend>`.
#[derive(::id_effect::ProviderSpecDerive)]
#[provides(NixEvaluatorKey)]
pub struct ProcessNixEvalLive;

impl ProcessNixEvalLive {
    #[allow(clippy::new_ret_no_self)] // ProviderSpecDerive factory returns capability key
    fn new() -> NixEvaluatorKey {
        Arc::new(ProcessNixEval)
    }
}

/// Filesystem-backed snapshot store rooted at `testdata/goldens/`.
#[derive(::id_effect::ProviderSpecDerive)]
#[provides(SnapshotStoreKey)]
pub struct FsSnapshotStoreLive;

impl FsSnapshotStoreLive {
    #[allow(clippy::new_ret_no_self)] // ProviderSpecDerive factory returns capability key
    fn new() -> SnapshotStoreKey {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("testdata/goldens");
        SnapshotStore::new(root)
    }
}

/// Wall-clock [`Clock`] without ComputeFabric/Sysinfo telemetry startup cost.
#[derive(Debug, Default, Clone, Copy)]
pub struct StdClock;

impl Clock for StdClock {
    fn now(&self) -> Instant {
        Instant::now()
    }

    fn sleep(&self, duration: Duration) -> Effect<(), Never, ()> {
        Effect::new(move |_env| {
            std::thread::sleep(duration);
            Ok::<(), Never>(())
        })
    }

    fn sleep_until(&self, deadline: Instant) -> Effect<(), Never, ()> {
        let now = Instant::now();
        if deadline <= now {
            return Effect::new(|_| Ok::<(), Never>(()));
        }
        self.sleep(deadline.duration_since(now))
    }
}

/// Production clock: [`StdClock`] (no ThreadSleepRuntime fabric install).
#[derive(::id_effect::ProviderSpecDerive)]
#[provides(ClockKey)]
pub struct LiveClockLive;

impl LiveClockLive {
    #[allow(clippy::new_ret_no_self)] // ProviderSpecDerive factory returns capability key
    fn new() -> ClockKey {
        Arc::new(StdClock)
    }
}

/// Semaphore-backed worker pool (default max = CPU count).
#[derive(::id_effect::ProviderSpecDerive)]
#[provides(NixWorkerPoolKey)]
pub struct SemaphoreWorkerPoolLive;

impl SemaphoreWorkerPoolLive {
    #[allow(clippy::new_ret_no_self)] // ProviderSpecDerive factory returns capability key
    fn new() -> NixWorkerPoolKey {
        Arc::new(SemaphoreWorkerPool::default_live())
    }
}

/// Deterministic test clock for unit tests.
#[derive(::id_effect::ProviderSpecDerive)]
#[provides(ClockKey)]
pub struct AssayTestClockLive;

impl AssayTestClockLive {
    #[allow(clippy::new_ret_no_self)] // ProviderSpecDerive factory returns capability key
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
        self.values.lock().unwrap().insert(expr.into(), result);
    }
}

impl EvalBackend for MockNixEval {
    fn eval_json(&self, expr: &str) -> EvalResult {
        if let Some(hit) = self.values.lock().unwrap().get(expr).cloned() {
            return hit;
        }
        // Batched eq form: [(left) (right)] — resolve sides independently.
        if let Some((left, right)) = split_eq_pair(expr) {
            let l = self.eval_json(left);
            let r = self.eval_json(right);
            return match (l, r) {
                (EvalResult::Ok(a), EvalResult::Ok(b)) => EvalResult::Ok(Value::Array(vec![a, b])),
                (EvalResult::Err(e), _) | (_, EvalResult::Err(e)) => EvalResult::Err(e),
            };
        }
        EvalResult::Ok(Value::Null)
    }
}

/// Parse assay batched-eq wrapper `[({left}) ({right})]`.
fn split_eq_pair(expr: &str) -> Option<(&str, &str)> {
    let trimmed = expr.trim();
    let inner = trimmed.strip_prefix('[')?.strip_suffix(']')?.trim();
    let (left_raw, right_raw) = split_top_level_pair(inner)?;
    let left = unwrap_parens(left_raw.trim())?;
    let right = unwrap_parens(right_raw.trim())?;
    Some((left, right))
}

fn unwrap_parens(s: &str) -> Option<&str> {
    s.strip_prefix('(')?.strip_suffix(')')
}

fn split_top_level_pair(s: &str) -> Option<(&str, &str)> {
    let mut depth = 0i32;
    for (i, ch) in s.char_indices() {
        match ch {
            '(' | '[' | '{' => depth += 1,
            ')' | ']' | '}' => depth -= 1,
            ' ' | '\t' | '\n' if depth == 0 => {
                let left = s[..i].trim();
                let right = s[i..].trim();
                if !left.is_empty() && !right.is_empty() {
                    return Some((left, right));
                }
            }
            _ => {}
        }
    }
    None
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

mock_capability!(
    MockWorkerPoolLive,
    NixWorkerPoolKey,
    "pool/mock",
    || Arc::new(MockWorkerPool::new(8)) as NixWorkerPoolKey
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

#[derive(::id_effect::ProviderSpecDerive)]
#[provides(PathInfoStoreKey)]
pub struct SqlitePathInfoStoreLive;

impl SqlitePathInfoStoreLive {
    #[allow(clippy::new_ret_no_self)] // ProviderSpecDerive factory returns capability key
    fn new() -> PathInfoStoreKey {
        let root = std::env::var("ASSAY_NIX_STORE").unwrap_or_else(|_| "/nix".into());
        Arc::new(SqlitePathInfoStore::new(root))
    }
}

mock_capability!(
    MockPathInfoStoreLive,
    PathInfoStoreKey,
    "pathinfo/mock",
    || Arc::new(MockPathInfoStore::default()) as PathInfoStoreKey
);

/// Default live provider list for `run_with` at the application edge.
pub fn live_providers() -> [id_effect::ProviderBox; 5] {
    [
        provide!(ProcessNixEvalLive),
        provide!(FsSnapshotStoreLive),
        provide!(LiveClockLive),
        provide!(SemaphoreWorkerPoolLive),
        provide!(SqlitePathInfoStoreLive),
    ]
}

#[cfg(test)]
pub fn mock_providers() -> [id_effect::ProviderBox; 5] {
    [
        provide!(MockNixEvalLive),
        provide!(MockSnapshotStoreLive),
        provide!(AssayTestClockLive),
        provide!(MockWorkerPoolLive),
        provide!(MockPathInfoStoreLive),
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
        assert!(env.has::<Cap<NixWorkerPoolKey>>());
        assert!(env.has::<Cap<PathInfoStoreKey>>());
    }

    #[test]
    fn build_env_materializes_all_mock_capabilities() {
        let env = build_env(mock_providers()).expect("env");
        assert!(env.has::<Cap<NixEvaluatorKey>>());
        assert!(env.has::<Cap<SnapshotStoreKey>>());
        assert!(env.has::<Cap<ClockKey>>());
        assert!(env.has::<Cap<NixWorkerPoolKey>>());
        assert!(env.has::<Cap<PathInfoStoreKey>>());
    }

    #[test]
    fn run_test_reads_all_caps() {
        let env = AssayEnv::from_env(build_env(mock_providers()).expect("env"));
        let effect: Effect<(bool, bool, bool, bool, bool), (), AssayEnv> = Effect::new(|env| {
            let _nix = Needs::<NixEvaluatorKey>::need(env);
            let _snap = Needs::<SnapshotStoreKey>::need(env);
            let _clock = Needs::<ClockKey>::need(env);
            let _pool = Needs::<NixWorkerPoolKey>::need(env);
            let _pi = Needs::<PathInfoStoreKey>::need(env);
            Ok((true, true, true, true, true))
        });
        let exit = run_test(effect, env);
        assert_eq!(exit, Exit::Success((true, true, true, true, true)));
    }

    #[test]
    fn mock_nix_eval_returns_configured_values() {
        let mock = Arc::new(MockNixEval::default());
        mock.set("x", EvalResult::Ok(serde_json::json!(42)));
        assert_eq!(mock.eval_json("x"), EvalResult::Ok(serde_json::json!(42)));
    }

    #[test]
    fn fs_snapshot_store_live_roots_at_goldens() {
        let env = build_env([provide!(FsSnapshotStoreLive)]).expect("env");
        let store = env.get::<Cap<SnapshotStoreKey>>();
        assert!(store.root.ends_with("testdata/goldens"));
    }

    #[test]
    fn fake_store_denies_ifd_by_default() {
        assert!(!FakeStore.allow_ifd());
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

    #[test]
    fn mock_nix_eval_batched_eq_pair() {
        let mock = Arc::new(MockNixEval::default());
        mock.set("1", EvalResult::Ok(serde_json::json!(1)));
        mock.set("2", EvalResult::Ok(serde_json::json!(2)));
        let batched = "[ (1) (2) ]";
        assert_eq!(
            mock.eval_json(batched),
            EvalResult::Ok(serde_json::json!([1, 2]))
        );
        assert_eq!(
            mock.eval_json("missing"),
            EvalResult::Ok(serde_json::json!(null))
        );
    }

    #[test]
    fn mock_nix_eval_batched_eq_propagates_error() {
        let mock = Arc::new(MockNixEval::default());
        mock.set(
            "bad",
            EvalResult::Err(AssayOutcome::EvalError {
                kind: "throw".into(),
                message: "boom".into(),
                span: None,
            }),
        );
        let batched = "[ (bad) (1) ]";
        assert!(matches!(mock.eval_json(batched), EvalResult::Err(_)));
    }

    #[test]
    fn std_clock_sleep_until_past_is_noop() {
        let clock = StdClock;
        let past = Instant::now() - Duration::from_secs(1);
        let exit = id_effect::run_test(clock.sleep_until(past), ());
        assert!(matches!(exit, Exit::Success(())));
    }

    #[test]
    fn std_clock_sleep_runs() {
        let clock = StdClock;
        let exit = id_effect::run_test(clock.sleep(Duration::from_millis(1)), ());
        assert!(matches!(exit, Exit::Success(())));
    }

    #[test]
    fn std_clock_sleep_until_future_waits() {
        let clock = StdClock;
        let future = Instant::now() + Duration::from_millis(1);
        let exit = id_effect::run_test(clock.sleep_until(future), ());
        assert!(matches!(exit, Exit::Success(())));
    }

    #[test]
    fn split_eq_pair_requires_wrapped_operands() {
        assert!(split_eq_pair("[ 1 ) ( 2 ]").is_none());
        assert!(unwrap_parens("(no-close").is_none());
    }

    #[test]
    fn split_eq_pair_parsing_edge_cases() {
        assert_eq!(split_eq_pair("[ (1) (2) ]"), Some(("1", "2")));
        assert!(split_eq_pair("not").is_none());
        assert!(split_eq_pair("[ (only) ]").is_none());
        assert!(split_eq_pair("[ 1 2 ]").is_none());
    }

    #[test]
    fn split_top_level_pair_respects_nesting() {
        assert_eq!(
            split_top_level_pair("(a (b c)) (d)"),
            Some(("(a (b c))", "(d)"))
        );
        assert!(split_top_level_pair("single").is_none());
    }

    #[test]
    fn mock_nix_eval_batched_right_side_error() {
        let mock = Arc::new(MockNixEval::default());
        mock.set("1", EvalResult::Ok(serde_json::json!(1)));
        mock.set(
            "bad",
            EvalResult::Err(AssayOutcome::EvalError {
                kind: "throw".into(),
                message: "boom".into(),
                span: None,
            }),
        );
        assert!(matches!(
            mock.eval_json("[ (1) (bad) ]"),
            EvalResult::Err(_)
        ));
    }

    #[test]
    fn split_top_level_pair_bracket_and_brace_depth() {
        assert_eq!(split_top_level_pair("[a] {b}"), Some(("[a]", "{b}")));
        assert!(split_top_level_pair("   ").is_none());
        assert!(split_top_level_pair("foo ").is_none());
        assert!(split_top_level_pair(" foo").is_none());
    }
}
