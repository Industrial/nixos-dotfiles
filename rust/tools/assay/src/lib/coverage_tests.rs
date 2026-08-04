//! Cross-module coverage tests for batch eval, schema value-mode, and run paths.

use std::path::PathBuf;
use std::sync::Arc;

use id_effect::{build_env, Cap, Exit, FromEnv};
use id_effect::Clock;
use serde_json::{json, Value};

use crate::batch::{
    is_batchable, partition_cases, run_batch, BATCH_MARKER, FORCE_BATCH_JSON_EVAL,
};
use crate::caps::{mock_providers, AssayEnv, MockNixEval, NixEvaluatorKey, StdClock};
use crate::claims::Claim;
use crate::eval::{EvalBackend, EvalResult};
use crate::optics_json::{fold_object_keys, value_contains_subset};
use crate::outcome::AssayOutcome;
use crate::pool::{NixWorkerPool, SemaphoreWorkerPool};
use crate::prop::{run_prop_by_name, Gen, BUILTIN_PROP_NAMES};
use crate::report::{
    collect_formatted_lines, format_line, report_outcomes_stdout, ReportFormat,
};
use crate::run::{summarize, summarize_exits, RunSummary, SuiteReport};
use crate::schema::{decode_claim_json, encode_claim_json};
use crate::snapshot::SnapshotStore;
use crate::verdict::{exit_to_outcome, outcome_to_exit, CaseVerdict, InfraError};

struct BatchJsonEval {
    inner: MockNixEval,
}

impl EvalBackend for BatchJsonEval {
    fn eval_json(&self, expr: &str) -> EvalResult {
        if expr.contains(BATCH_MARKER) {
            return self.batch_results(expr);
        }
        self.inner.eval_json(expr)
    }
}

impl BatchJsonEval {
    fn new() -> Self {
        Self {
            inner: MockNixEval::default(),
        }
    }

    fn with_inner(mut self, setup: impl FnOnce(&MockNixEval)) -> Self {
        setup(&self.inner);
        self
    }

    fn batch_results(&self, _expr: &str) -> EvalResult {
        EvalResult::Ok(json!({
            BATCH_MARKER: true,
            "results": [
                {
                    "i": 0,
                    "name": "eq_ok",
                    "kind": "eq",
                    "left": { "ok": true, "value": 1 },
                    "right": { "ok": true, "value": 1 }
                },
                {
                    "i": 1,
                    "name": "eq_fail",
                    "kind": "eq",
                    "left": { "ok": true, "value": 1 },
                    "right": { "ok": true, "value": 2 }
                },
                {
                    "i": 2,
                    "name": "subset_ok",
                    "kind": "subset",
                    "primary": { "ok": true, "value": {"a": 1, "b": 2} }
                },
                {
                    "i": 3,
                    "name": "has_ok",
                    "kind": "hasAttrs",
                    "primary": { "ok": true, "keys": ["a", "b"] }
                },
                {
                    "i": 4,
                    "name": "snap",
                    "kind": "snapshot",
                    "primary": { "ok": true, "value": {"x": 1} }
                }
            ]
        }))
    }
}

fn mock_env(eval: Arc<dyn EvalBackend + Send + Sync>) -> AssayEnv {
    let mut built = build_env(mock_providers()).expect("env");
    built.insert::<Cap<NixEvaluatorKey>>(eval);
    AssayEnv::from_env(built)
}

#[test]
fn is_batchable_classifies_claim_variants() {
    assert!(is_batchable(&Claim::Eq {
        left_expr: "1".into(),
        right_expr: "1".into(),
    }));
    assert!(is_batchable(&Claim::Subset {
        expr: "x".into(),
        expected_subset: json!({}),
    }));
    assert!(!is_batchable(&Claim::EqValues {
        left: json!(1),
        right: json!(1),
    }));
    assert!(!is_batchable(&Claim::Throws {
        expr: "x".into(),
        pattern: None,
    }));
    assert!(!is_batchable(&Claim::Law {
        name: "merge_idempotent".into(),
        seed: 1,
    }));
}

#[test]
fn run_batch_mock_covers_eq_subset_hasattrs_snapshot() {
    let cases = vec![
        (
            "eq_ok".into(),
            Claim::Eq {
                left_expr: "1".into(),
                right_expr: "1".into(),
            },
        ),
        (
            "eq_fail".into(),
            Claim::Eq {
                left_expr: "1".into(),
                right_expr: "2".into(),
            },
        ),
        (
            "subset_ok".into(),
            Claim::Subset {
                expr: "v".into(),
                expected_subset: json!({"a": 1}),
            },
        ),
        (
            "has_ok".into(),
            Claim::HasAttrs {
                expr: "v".into(),
                attrs: vec!["a".into(), "b".into()],
            },
        ),
        (
            "snap".into(),
            Claim::Snapshot {
                name: "__assay_no_such_golden__".into(),
                expr: "v".into(),
            },
        ),
    ];
    let store = SnapshotStore::new(PathBuf::from("/tmp/assay-coverage-goldens"));
    let eval = Arc::new(BatchJsonEval::new());
    let outs = run_batch(&cases, eval.as_ref(), &store).expect("batch");
    assert_eq!(outs.len(), 5);
    assert!(matches!(outs[0].1, Exit::Success(CaseVerdict::Pass)));
    assert!(matches!(outs[1].1, Exit::Success(CaseVerdict::AssertFail { .. })));
    assert!(matches!(outs[2].1, Exit::Success(CaseVerdict::Pass)));
    assert!(matches!(outs[3].1, Exit::Success(CaseVerdict::Pass)));
    assert!(matches!(
        outs[4].1,
        Exit::Success(CaseVerdict::SnapshotMismatch { .. })
    ));
}



#[test]
fn partition_puts_value_mode_claims_in_isolated() {
    let (batch, iso) = partition_cases(vec![
        (
            "b".into(),
            Claim::Eq {
                left_expr: "1".into(),
                right_expr: "1".into(),
            },
        ),
        (
            "v".into(),
            Claim::EqValues {
                left: json!(1),
                right: json!(1),
            },
        ),
    ]);
    assert_eq!(batch.len(), 1);
    assert_eq!(iso.len(), 1);
    assert_eq!(iso[0].0, "v");
}

fn all_outcome_variants() -> Vec<AssayOutcome> {
    vec![
        AssayOutcome::Pass,
        AssayOutcome::Fail {
            claim: "eq".into(),
            left: None,
            right: None,
            diff: "d".into(),
        },
        AssayOutcome::EvalError {
            kind: "throw".into(),
            message: "m".into(),
            span: None,
        },
        AssayOutcome::Recursion,
        AssayOutcome::Timeout,
        AssayOutcome::ResourceLeak,
        AssayOutcome::SnapshotMismatch {
            path: "p".into(),
            diff: "snap".into(),
        },
        AssayOutcome::Counterexample {
            seed: 1,
            shrunk: json!({}),
        },
    ]
}

#[test]
fn report_human_and_tap_cover_all_outcome_marks() {
    for (i, outcome) in all_outcome_variants().into_iter().enumerate() {
        let name = format!("case_{i}");
        let human = format_line(i, &name, &outcome, ReportFormat::Human).body;
        assert!(human.contains(&name));
        let tap = format_line(i + 1, &name, &outcome, ReportFormat::Tap).body;
        if matches!(outcome, AssayOutcome::Pass) {
            assert!(tap.starts_with("ok "));
        } else {
            assert!(tap.starts_with("not ok "));
        }
    }
}

#[test]
fn collect_formatted_lines_json_is_empty() {
    let outcomes = vec![("a".into(), AssayOutcome::Pass)];
    assert!(collect_formatted_lines(&outcomes, ReportFormat::Json).is_empty());
}

#[test]
fn report_outcomes_stdout_smoke() {
    let outcomes = vec![("a".into(), AssayOutcome::Pass)];
    let summary = RunSummary {
        total: 1,
        passed: 1,
        failed: 0,
        errored: 0,
    };
    report_outcomes_stdout(&outcomes, ReportFormat::Human, &summary).unwrap();
}

#[test]
fn summarize_exits_counts_pass_fail_error() {
    let outcomes = vec![
        (
            "p".into(),
            Exit::Success(CaseVerdict::Pass),
        ),
        (
            "f".into(),
            Exit::Success(CaseVerdict::AssertFail {
                claim: "eq".into(),
                left: None,
                right: None,
                diff: "d".into(),
            }),
        ),
        (
            "e".into(),
            Exit::Failure(id_effect::Cause::Fail(InfraError::Timeout {
                case: "e".into(),
                limit_ms: 1,
            })),
        ),
    ];
    let s = summarize_exits(&outcomes);
    assert_eq!(s.total, 3);
    assert_eq!(s.passed, 1);
    assert_eq!(s.failed, 1);
    assert_eq!(s.errored, 1);
}

#[test]
fn summarize_report_delegates_to_exits() {
    let report = SuiteReport {
        outcomes: vec![("x".into(), Exit::Success(CaseVerdict::Pass))],
    };
    let s = crate::run::summarize(&report);
    assert_eq!(s.passed, 1);
}

#[test]
fn fold_object_keys_noop_on_non_object() {
    let mut count = 0;
    fold_object_keys(&json!(1), |_| count += 1);
    assert_eq!(count, 0);
    fold_object_keys(&json!([1]), |_| count += 1);
    assert_eq!(count, 0);
}

#[test]
fn subset_array_equality_branch() {
    let a = json!([1, 2]);
    let b = json!([1, 2]);
    assert!(value_contains_subset(&a, &b));
    assert!(!value_contains_subset(&a, &json!([1])));
}

#[test]
fn gen_edge_sizes_and_builtin_props() {
    let mut g = Gen::new(99);
    assert_eq!(g.gen_u32(1), 0);
    assert!(g.gen_string(0).is_empty());
    for name in BUILTIN_PROP_NAMES {
        let _ = run_prop_by_name(name, 1, 3);
    }
}

#[test]
fn semaphore_pool_acquire_and_release() {
    let pool = SemaphoreWorkerPool::new(2);
    let g1 = pool.acquire().unwrap();
    let g2 = pool.acquire().unwrap();
    assert_eq!(pool.stats().in_flight(), 2);
    drop(g1);
    drop(g2);
    assert_eq!(pool.stats().in_flight(), 0);
    assert!(pool.stats().max_in_flight() >= 2);
}

#[test]
fn mock_nix_eval_batched_nested_and_invalid() {
    let mock = Arc::new(MockNixEval::default());
    mock.set("inner", EvalResult::Ok(json!(1)));
    mock.set("other", EvalResult::Ok(json!(2)));
    // nested parens in left side
    let nested = "[ (inner) (other) ]";
    assert_eq!(
        mock.eval_json(nested),
        EvalResult::Ok(json!([1, 2]))
    );
    // not a batched pair → null
    assert_eq!(mock.eval_json("not-batch"), EvalResult::Ok(json!(null)));
    // malformed batch
    assert_eq!(mock.eval_json("[broken"), EvalResult::Ok(json!(null)));
    // left error propagates
    mock.set(
        "bad",
        EvalResult::Err(AssayOutcome::EvalError {
            kind: "throw".into(),
            message: "x".into(),
            span: None,
        }),
    );
    assert!(matches!(mock.eval_json("[ (bad) (other) ]"), EvalResult::Err(_)));
}

#[test]
fn std_clock_sleep_future_path() {
    use std::time::{Duration, Instant};
    let clock = StdClock;
    let future = clock.sleep(Duration::from_millis(5));
    id_effect::runtime::run_blocking(future, ()).expect("sleep");
    let until = clock.sleep_until(Instant::now() + Duration::from_millis(1));
    id_effect::runtime::run_blocking(until, ()).expect("sleep_until");
}

#[test]
fn outcome_to_exit_unknown_eval_kind() {
    let err = AssayOutcome::EvalError {
        kind: "custom".into(),
        message: "msg".into(),
        span: None,
    };
    assert!(matches!(outcome_to_exit(err.clone()), Exit::Success(CaseVerdict::EvalThrow { .. })));
    assert_eq!(exit_to_outcome(outcome_to_exit(err)), AssayOutcome::EvalError {
        kind: "custom".into(),
        message: "msg".into(),
        span: None,
    });
}

#[test]
fn outcome_to_exit_panic_and_timeout_paths() {
    let panic = AssayOutcome::EvalError {
        kind: "panic".into(),
        message: "boom".into(),
        span: None,
    };
    assert!(matches!(outcome_to_exit(panic), Exit::Failure(_)));
    assert!(matches!(outcome_to_exit(AssayOutcome::Timeout), Exit::Failure(_)));
    assert!(matches!(outcome_to_exit(AssayOutcome::ResourceLeak), Exit::Failure(_)));
}

#[test]
fn value_mode_claims_roundtrip() {
    for claim in [
        Claim::EqValues {
            left: json!(1),
            right: json!(1),
        },
        Claim::SubsetValues {
            actual: json!({"a": 1}),
            expected_subset: json!({"a": 1}),
        },
        Claim::HasAttrsValues {
            actual: json!({"a": 1}),
            attrs: vec!["a".into()],
        },
    ] {
        let encoded = encode_claim_json(&claim);
        let decoded = decode_claim_json(&encoded).expect("decode");
        assert_eq!(decoded, claim);
    }
}

struct ForceBatchEval {
    payload: Value,
}

impl EvalBackend for ForceBatchEval {
    fn eval_json(&self, expr: &str) -> EvalResult {
        if expr.contains(BATCH_MARKER) {
            EvalResult::Ok(self.payload.clone())
        } else {
            EvalResult::Ok(json!(null))
        }
    }
}

#[test]
fn force_batch_json_eval_happy_path() {
    FORCE_BATCH_JSON_EVAL.with(|f| {
        f.set(true);
        let cases = vec![(
            "eq".into(),
            Claim::Eq {
                left_expr: "1".into(),
                right_expr: "1".into(),
            },
        )];
        let eval = ForceBatchEval {
            payload: json!({
                BATCH_MARKER: true,
                "results": [{"kind": "eq", "left": {"ok": true, "value": 1}, "right": {"ok": true, "value": 1}}]
            }),
        };
        let store = SnapshotStore::new(PathBuf::from("/tmp/assay-force-batch"));
        let outs = run_batch(&cases, &eval, &store).expect("batch");
        assert_eq!(outs.len(), 1);
        f.set(false);
    });
}
