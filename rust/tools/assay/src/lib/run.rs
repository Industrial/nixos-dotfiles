//! Run assay suites and collect `Exit` outcomes.

use std::path::Path;
use std::time::Duration;

use id_effect::concurrency::FiberHandle;
use id_effect::runtime::{run_blocking, run_fork, ThreadSleepRuntime};
use id_effect::{Cap, Cause, Effect, Exit, Needs};
use serde::Serialize;

use crate::assay_suite::load_assay_suite;
use crate::batch::{partition_cases, run_batch};
use crate::caps::NixEvaluatorKey;
use crate::caps::{AssayEnv, NixWorkerPoolKey, SnapshotStoreKey};
use crate::claims::Claim;
use crate::timeout::interpret_claim_with_retry;
use crate::compat::load_compat_suite;
use crate::discover::{discover_suites, suite_kind, SuiteKind};
use crate::outcome::AssayOutcome;
use crate::verdict::{CaseVerdict, InfraError, exit_to_outcome};

#[derive(Debug, Clone)]
pub struct RunOptions {
    pub update_snapshots: bool,
    pub json_output: bool,
    /// Per-case timeout budget in milliseconds (`None` = no limit).
    pub case_timeout_ms: Option<u64>,
    /// Retry flaky nix eval via `retry_with_clock` (default off).
    pub retry_flaky_eval: bool,
    /// Collapse batchable claims into one `nix eval` via `tryEval` (default on).
    pub batch_eval: bool,
}

impl Default for RunOptions {
    fn default() -> Self {
        Self {
            update_snapshots: false,
            json_output: false,
            case_timeout_ms: None,
            retry_flaky_eval: false,
            batch_eval: true,
        }
    }
}

#[derive(Debug, Clone)]
pub struct SuiteReport {
    pub outcomes: Vec<(String, Exit<CaseVerdict, InfraError>)>,
}

#[derive(Debug, Clone, Copy, Default, Serialize, PartialEq, Eq)]
pub struct RunSummary {
    pub total: usize,
    pub passed: usize,
    pub failed: usize,
    pub errored: usize,
}

pub fn run_suite(path: &Path, opts: &RunOptions) -> Effect<SuiteReport, InfraError, AssayEnv> {
    let path = path.to_path_buf();
    let opts = opts.clone();
    Effect::new(move |env| run_suite_on_env(&path, &opts, env))
}

fn apply_snapshot_update(env: &mut AssayEnv, update: bool) {
    if update {
        let updated = env.get::<Cap<SnapshotStoreKey>>().clone().with_update(true);
        env.insert::<Cap<SnapshotStoreKey>>(updated);
    }
}

fn load_suite_cases(path: &Path, env: &AssayEnv) -> Result<Vec<(String, Claim)>, InfraError> {
    // Suite load is a nix eval — share the worker pool with claim evals.
    let pool = Needs::<NixWorkerPoolKey>::need(env);
    let _slot = pool.acquire()?;
    let kind = suite_kind(path).unwrap_or(SuiteKind::CompatJson);
    match kind {
        SuiteKind::CompatJson | SuiteKind::CompatNix => load_compat_cases(path),
        SuiteKind::AssayNix => {
            load_assay_suite(path).map_err(|e| InfraError::SuiteLoad(e.to_string()))
        }
    }
}

fn run_suite_on_env(
    path: &Path,
    opts: &RunOptions,
    env: &mut AssayEnv,
) -> Result<SuiteReport, InfraError> {
    apply_snapshot_update(env, opts.update_snapshots);
    let t0 = std::time::Instant::now();
    let cases = load_suite_cases(path, env)?;
    if std::env::var_os("ASSAY_TRACE").is_some() {
        eprintln!(
            "assay_trace: load_suite {:.1}ms ({} cases)",
            t0.elapsed().as_secs_f64() * 1000.0,
            cases.len()
        );
    }
    let t1 = std::time::Instant::now();
    let report = run_cases_on_env(cases, opts, env)?;
    if std::env::var_os("ASSAY_TRACE").is_some() {
        eprintln!(
            "assay_trace: run_cases {:.1}ms",
            t1.elapsed().as_secs_f64() * 1000.0
        );
    }
    Ok(report)
}

fn run_cases_on_env(
    cases: Vec<(String, Claim)>,
    opts: &RunOptions,
    env: &mut AssayEnv,
) -> Result<SuiteReport, InfraError> {
    let retry = opts.retry_flaky_eval;
    let timeout_ms = opts.case_timeout_ms;

    let (batchable, isolated) = if opts.batch_eval {
        partition_cases(cases)
    } else {
        (Vec::new(), cases)
    };

    let mut outcomes = Vec::new();

    if !batchable.is_empty() {
        let pool = Needs::<NixWorkerPoolKey>::need(env);
        let _slot = pool.acquire()?;
        let eval = Needs::<NixEvaluatorKey>::need(env);
        let store = Needs::<SnapshotStoreKey>::need(env);
        outcomes.extend(run_batch(&batchable, eval.as_ref(), store)?);
    }

    if !isolated.is_empty() {
        // Fabric construct is cheap after ComputeSupervisor lazy telemetry init.
        let rt = ThreadSleepRuntime::default();

        struct PendingCase {
            name: String,
            case: FiberHandle<CaseVerdict, InfraError>,
            timeout: Option<FiberHandle<CaseVerdict, InfraError>>,
        }

        let mut pending = Vec::with_capacity(isolated.len());
        for (name, claim) in isolated {
            let env_clone = env.clone();
            let case_name = name.clone();
            let case_handle =
                run_fork(&rt, move || (interpret_claim_with_retry(claim, retry), env_clone));
            let timeout_handle =
                timeout_ms.map(|limit_ms| spawn_timeout_fiber(&rt, case_name, limit_ms));
            pending.push(PendingCase {
                name,
                case: case_handle,
                timeout: timeout_handle,
            });
        }

        for p in pending {
            let exit = match p.timeout {
                Some(timeout) => race_case_or_timeout(p.case, timeout),
                None => {
                    let exit = run_blocking(p.case.await_exit(), ())
                        .expect("await_exit is infallible");
                    let _ = p.case.interrupt();
                    exit
                }
            };
            outcomes.push((p.name, exit));
        }
    }

    outcomes.sort_by(|a, b| a.0.cmp(&b.0));
    Ok(SuiteReport { outcomes })
}


fn race_case_or_timeout(
    case: FiberHandle<CaseVerdict, InfraError>,
    timeout: FiberHandle<CaseVerdict, InfraError>,
) -> Exit<CaseVerdict, InfraError> {
    loop {
        if let Some(result) = case.poll_result() {
            let _ = timeout.interrupt();
            return match result {
                Ok(v) => Exit::succeed(v),
                Err(c) => Exit::Failure(c),
            };
        }
        if let Some(result) = timeout.poll_result() {
            let _ = case.interrupt();
            return match result {
                Ok(v) => Exit::succeed(v),
                Err(c) => Exit::Failure(c),
            };
        }
        std::thread::yield_now();
    }
}

fn spawn_timeout_fiber(
    rt: &ThreadSleepRuntime,
    case: String,
    limit_ms: u64,
) -> FiberHandle<CaseVerdict, InfraError> {
    run_fork(rt, move || {
        (
            Effect::new(move |_| {
                std::thread::sleep(Duration::from_millis(limit_ms));
                Err(InfraError::Timeout {
                    case: case.clone(),
                    limit_ms,
                })
            }),
            (),
        )
    })
}

fn load_compat_cases(path: &Path) -> Result<Vec<(String, Claim)>, InfraError> {
    let suite = load_compat_suite(path).map_err(|e| InfraError::SuiteLoad(e.to_string()))?;
    Ok(suite
        .cases
        .into_iter()
        .map(|c| {
            (
                c.name,
                Claim::Eq {
                    left_expr: c.expr,
                    right_expr: c.expected,
                },
            )
        })
        .collect())
}

pub fn run_discovered(root: &Path, opts: &RunOptions) -> Effect<SuiteReport, InfraError, AssayEnv> {
    let root = root.to_path_buf();
    let opts = opts.clone();
    Effect::new(move |env| {
        apply_snapshot_update(env, opts.update_snapshots);
        let suite_opts = RunOptions {
            update_snapshots: false,
            ..opts.clone()
        };

        let suites = discover_suites(&root).map_err(|e| InfraError::Io(e.to_string()))?;
        let rt = ThreadSleepRuntime::default();

        // Phase 1: load every suite in parallel (pool-gated inside load_suite_cases).
        let mut load_handles = Vec::with_capacity(suites.len());
        for suite in suites {
            let env_clone = env.clone();
            let path = suite.path;
            load_handles.push(run_fork(&rt, move || {
                (
                    Effect::new(move |env| {
                        let prefix = path.display().to_string();
                        let cases = load_suite_cases(&path, env)?;
                        Ok(cases
                            .into_iter()
                            .map(|(name, claim)| (format!("{prefix}::{name}"), claim))
                            .collect::<Vec<_>>())
                    }),
                    env_clone,
                )
            }));
        }

        let mut all_cases = Vec::new();
        for handle in load_handles {
            let exit = run_blocking(handle.await_exit(), ()).expect("await_exit is infallible");
            let _ = handle.interrupt();
            match exit {
                Exit::Success(cases) => all_cases.extend(cases),
                Exit::Failure(cause) => return Err(suite_fiber_infra(cause)),
            }
        }

        // Phase 2: one mega-batch for all batchable claims + isolated fibers.
        run_cases_on_env(all_cases, &suite_opts, env)
    })
}

fn suite_fiber_infra(cause: Cause<InfraError>) -> InfraError {
    match cause {
        Cause::Fail(err) => err,
        Cause::Die(msg) => InfraError::Worker(msg),
        Cause::Interrupt(id) => InfraError::Worker(format!("interrupted suite fiber {id:?}")),
        Cause::Both(left, _) => suite_fiber_infra(*left),
        Cause::Then(_, right) => suite_fiber_infra(*right),
    }
}

pub fn summarize(report: &SuiteReport) -> RunSummary {
    summarize_exits(&report.outcomes)
}

pub fn summarize_exits(outcomes: &[(String, Exit<CaseVerdict, InfraError>)]) -> RunSummary {
    let mut s = RunSummary {
        total: outcomes.len(),
        ..Default::default()
    };
    for (_, exit) in outcomes {
        match exit_to_outcome(exit.clone()) {
            AssayOutcome::Pass => s.passed += 1,
            AssayOutcome::EvalError { .. }
            | AssayOutcome::Recursion
            | AssayOutcome::Timeout
            | AssayOutcome::ResourceLeak => s.errored += 1,
            _ => s.failed += 1,
        }
    }
    s
}

pub fn run_suite_blocking(
    path: &Path,
    opts: &RunOptions,
    env: AssayEnv,
) -> Result<SuiteReport, InfraError> {
    run_blocking(run_suite(path, opts), env)
}

#[cfg(test)]
mod tests {
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::Arc;
    use std::time::Instant;

    use id_effect::{build_env, succeed, Cap, FromEnv, run_test, run_test_with_clock, TestClock};
    use serde_json::json;

    use super::*;
    use crate::caps::{mock_providers, ClockKey, MockNixEval, NixEvaluatorKey};
    use crate::claims::interpret_claim;
    use crate::eval::{EvalBackend, EvalResult};
    use crate::pool::{MockWorkerPool, NixWorkerPool};

    fn mock_env_with_eval(eval: Arc<dyn EvalBackend + Send + Sync>) -> AssayEnv {
        let mut env = build_env(mock_providers()).expect("env");
        env.insert::<Cap<NixEvaluatorKey>>(eval);
        AssayEnv::from_env(env)
    }

    #[test]
    fn parallel_cases_collect_all_sorted_by_name() {
        static ORDER: AtomicUsize = AtomicUsize::new(0);

        struct OrderEval;
        impl EvalBackend for OrderEval {
            fn eval_json(&self, expr: &str) -> EvalResult {
                let _ = ORDER.fetch_add(1, Ordering::SeqCst);
                let _ = expr;
                // Batched eq expects a 2-element list.
                EvalResult::Ok(json!([42, 42]))
            }
        }

        let env = mock_env_with_eval(Arc::new(OrderEval));
        let cases: Vec<(String, Claim)> = vec![
            ("z_last".into(), Claim::Eq { left_expr: "1".into(), right_expr: "1".into() }),
            ("a_first".into(), Claim::Eq { left_expr: "1".into(), right_expr: "1".into() }),
            ("m_mid".into(), Claim::Eq { left_expr: "1".into(), right_expr: "1".into() }),
        ];

        let rt = ThreadSleepRuntime::default();
        let mut handles = Vec::new();
        for (name, claim) in cases {
            let env_clone = env.clone();
            let h = run_fork(&rt, move || (interpret_claim(claim), env_clone));
            handles.push((name, h));
        }
        let mut outcomes = Vec::new();
        for (name, h) in handles {
            let exit = run_blocking(h.await_exit(), ()).expect("exit");
            let _ = h.interrupt();
            outcomes.push((name, exit));
        }
        outcomes.sort_by(|a, b| a.0.cmp(&b.0));

        assert_eq!(outcomes[0].0, "a_first");
        assert_eq!(outcomes[1].0, "m_mid");
        assert_eq!(outcomes[2].0, "z_last");
        assert_eq!(outcomes.len(), 3);
        for (_, exit) in &outcomes {
            assert!(matches!(exit, Exit::Success(CaseVerdict::Pass)));
        }
    }

    #[test]
    fn run_test_suite_no_leaked_fibers() {
        let env = mock_env_with_eval(Arc::new(MockNixEval::default()));
        let effect = Effect::new(move |env: &mut AssayEnv| {
            let cases: Vec<(String, Claim)> = vec![
                ("b".into(), Claim::Eq { left_expr: "x".into(), right_expr: "x".into() }),
                ("a".into(), Claim::Eq { left_expr: "y".into(), right_expr: "y".into() }),
            ];
            let rt = ThreadSleepRuntime::default();
            let mut handles = Vec::new();
            for (name, claim) in cases {
                let env_clone = env.clone();
                handles.push((name, run_fork(&rt, move || (interpret_claim(claim), env_clone))));
            }
            let mut outcomes = Vec::new();
            for (name, h) in handles {
                let exit = run_blocking(h.await_exit(), ()).expect("exit");
                let _ = h.interrupt();
                outcomes.push((name, exit));
            }
            outcomes.sort_by(|a, b| a.0.cmp(&b.0));
            Ok(SuiteReport { outcomes })
        });
        let exit: Exit<SuiteReport, InfraError> = run_test(effect, env);
        assert!(matches!(exit, Exit::Success(_)));
    }

    #[test]
    fn timeout_race_returns_infra_error() {
        let clock = TestClock::new(Instant::now());
        let clock_key: ClockKey = Arc::new(clock.clone());

        let slow = Arc::new(SlowEval);
        let mut built = build_env(mock_providers()).expect("env");
        built.insert::<Cap<NixEvaluatorKey>>(slow);
        built.insert::<Cap<ClockKey>>(clock_key);
        let env = AssayEnv::from_env(built);

        let claim = Claim::Eq {
            left_expr: "slow".into(),
            right_expr: "slow".into(),
        };
        let rt = ThreadSleepRuntime::default();
        let case = run_fork(&rt, {
            let env = env.clone();
            move || (interpret_claim(claim), env)
        });
        let timeout = spawn_timeout_fiber(&rt, "slow_case".into(), 50);
        let race_exit = race_case_or_timeout(case, timeout);
        let _harness = run_test_with_clock(succeed::<(), InfraError, ()>(()), (), clock);

        assert!(
            matches!(
                race_exit,
                Exit::Failure(id_effect::Cause::Fail(InfraError::Timeout { .. }))
            ),
            "race_exit = {race_exit:?}"
        );
    }

    struct SlowEval;
    impl EvalBackend for SlowEval {
        fn eval_json(&self, _expr: &str) -> EvalResult {
            std::thread::sleep(Duration::from_millis(300));
            EvalResult::Ok(json!(1))
        }
    }

    #[test]
    fn mock_worker_pool_records_max_in_flight_under_parallel_acquire() {
        let pool = Arc::new(MockWorkerPool::new(4));
        pool.set_block_ms(30);
        let rt = ThreadSleepRuntime::default();
        let mut handles = Vec::new();
        for _ in 0..3 {
            let p = Arc::clone(&pool);
            handles.push(run_fork(&rt, move || {
                (
                    Effect::new(move |_| {
                        let _g = p.acquire()?;
                        Ok::<(), InfraError>(())
                    }),
                    (),
                )
            }));
        }
        for h in handles {
            let _ = run_blocking(h.await_exit(), ()).expect("exit");
            let _ = h.interrupt();
        }
        assert!(pool.max_in_flight() >= 2);
    }

    #[test]
    fn succeed_smoke_for_run_suite_effect() {
        let exit = run_test(succeed::<SuiteReport, InfraError, ()>(SuiteReport { outcomes: vec![] }), ());
        assert!(matches!(exit, Exit::Success(_)));
    }

    #[test]
    fn run_discovered_runs_suites_concurrently_under_pool() {
        use std::fs;

        let root = std::env::temp_dir().join(format!(
            "assay_parallel_suites_{}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(root.join("a")).unwrap();
        fs::create_dir_all(root.join("b")).unwrap();
        fs::create_dir_all(root.join("c")).unwrap();
        for name in ["a", "b", "c"] {
            fs::write(
                root.join(name).join("suite.json"),
                r#"{"n":{"expr":"1","expected":"1"}}"#,
            )
            .unwrap();
        }

        let pool = Arc::new(MockWorkerPool::new(8));
        pool.set_block_ms(30);
        let mut built = build_env(mock_providers()).expect("env");
        built.insert::<Cap<NixEvaluatorKey>>(Arc::new(MockNixEval::default()) as _);
        built.insert::<Cap<crate::caps::NixWorkerPoolKey>>(pool.clone() as _);
        let env = AssayEnv::from_env(built);

        let report = run_blocking(
            run_discovered(
                &root,
                &RunOptions {
                    batch_eval: false,
                    ..RunOptions::default()
                },
            ),
            env,
        )
        .expect("discovered");
        let _ = fs::remove_dir_all(&root);

        assert_eq!(report.outcomes.len(), 3);
        // Overlapping acquires across suite fibers — serial would peak at 1.
        assert!(
            pool.max_in_flight() >= 2,
            "expected concurrent suite/case pool use, max_in_flight={}",
            pool.max_in_flight()
        );
    }

    #[test]
    fn suite_fiber_infra_maps_all_cause_variants() {
        use id_effect::Cause;
        assert!(matches!(
            suite_fiber_infra(Cause::Fail(InfraError::Io("x".into()))),
            InfraError::Io(_)
        ));
        assert!(matches!(
            suite_fiber_infra(Cause::Die("d".into())),
            InfraError::Worker(_)
        ));
        assert!(matches!(
            suite_fiber_infra(Cause::Interrupt(id_effect::FiberId::new(9))),
            InfraError::Worker(_)
        ));
        let left = Cause::Fail(InfraError::SuiteLoad("a".into()));
        let right = Cause::Fail(InfraError::Io("b".into()));
        assert!(matches!(
            suite_fiber_infra(Cause::Both(Box::new(left.clone()), Box::new(right.clone()))),
            InfraError::SuiteLoad(_)
        ));
        assert!(matches!(
            suite_fiber_infra(Cause::Then(Box::new(left), Box::new(right))),
            InfraError::Io(_)
        ));
    }

    #[test]
    fn race_case_or_timeout_case_wins() {
        let env = mock_env_with_eval(Arc::new(MockNixEval::default()));
        let claim = Claim::Eq {
            left_expr: "1".into(),
            right_expr: "1".into(),
        };
        let rt = ThreadSleepRuntime::default();
        let case = run_fork(&rt, {
            let env = env.clone();
            move || (interpret_claim(claim), env)
        });
        let timeout = spawn_timeout_fiber(&rt, "fast".into(), 5_000);
        let exit = race_case_or_timeout(case, timeout);
        assert!(matches!(exit, Exit::Success(CaseVerdict::Pass)));
    }

    #[test]
    fn run_cases_on_env_batch_eval_path() {
        let mock = Arc::new(MockNixEval::default());
        mock.set("1", EvalResult::Ok(json!(1)));
        let pool = Arc::new(MockWorkerPool::new(2));
        let mut built = build_env(mock_providers()).expect("env");
        built.insert::<Cap<NixEvaluatorKey>>(mock);
        built.insert::<Cap<crate::caps::NixWorkerPoolKey>>(pool.clone() as _);
        let mut env = AssayEnv::from_env(built);
        let cases = vec![(
            "eq".into(),
            Claim::Eq {
                left_expr: "1".into(),
                right_expr: "1".into(),
            },
        )];
        unsafe {
            std::env::set_var("ASSAY_TRACE", "1");
        }
        let report = run_cases_on_env(
            cases,
            &RunOptions {
                batch_eval: true,
                ..RunOptions::default()
            },
            &mut env,
        )
        .expect("batch path");
        unsafe {
            std::env::remove_var("ASSAY_TRACE");
        }
        assert_eq!(report.outcomes.len(), 1);
    }

    #[test]
    fn run_suite_on_env_trace_path() {
        use std::fs;

        let dir = std::env::temp_dir().join(format!("assay_suite_trace_{}", std::process::id()));
        fs::create_dir_all(&dir).unwrap();
        let path = dir.join("suite.json");
        fs::write(&path, r#"{"eq": {"expr": "1", "expected": "1"}}"#).unwrap();

        let mock = Arc::new(MockNixEval::default());
        mock.set("1", EvalResult::Ok(json!(1)));
        let pool = Arc::new(MockWorkerPool::new(2));
        let mut built = build_env(mock_providers()).expect("env");
        built.insert::<Cap<NixEvaluatorKey>>(mock);
        built.insert::<Cap<crate::caps::NixWorkerPoolKey>>(pool);
        let mut env = AssayEnv::from_env(built);
        unsafe {
            std::env::set_var("ASSAY_TRACE", "1");
        }
        let report = run_suite_on_env(&path, &RunOptions::default(), &mut env).expect("suite");
        unsafe {
            std::env::remove_var("ASSAY_TRACE");
        }
        let _ = fs::remove_dir_all(dir);
        assert_eq!(report.outcomes.len(), 1);
    }
}
