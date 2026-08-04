//! Targeted tests for branch coverage gaps across the assay lib.

use std::path::PathBuf;
use std::sync::Arc;

use id_effect::{Cap, Exit, FromEnv, build_env};
use serde_json::{Value, json};

use crate::assay_suite::parse_assay_suite;
use crate::caps::{AssayEnv, MockNixEval, NixEvaluatorKey, NixWorkerPoolKey, mock_providers};
use crate::claims::Claim;
use crate::discover::{SuiteKind, discover_suites, suite_kind};
use crate::eval::{EvalBackend, EvalResult, ProcessNixEval, classify_stderr};
use crate::laws::{law_merge_associativity, run_law_by_name};
use crate::outcome::AssayOutcome;
use crate::pool::MockWorkerPool;
use crate::prop::{Gen, run_prop_by_name};
use crate::run::{RunOptions, run_suite_blocking, summarize, summarize_exits};
use crate::schema::{decode_claim_json, encode_claim_json};
use crate::verdict::{CaseVerdict, InfraError, exit_to_outcome, outcome_to_exit};
use nixq::{fold_object_keys, structural_diff, value_has_attrs_via_traversal};

#[test]
fn verdict_unknown_eval_kind_maps_to_eval_throw() {
    let err = AssayOutcome::EvalError {
        kind: "custom_kind".into(),
        message: "weird".into(),
        span: None,
    };
    assert!(matches!(
        outcome_to_exit(err.clone()),
        Exit::Success(CaseVerdict::EvalThrow { .. })
    ));
    assert_eq!(
        exit_to_outcome(outcome_to_exit(err)),
        AssayOutcome::EvalError {
            kind: "custom_kind".into(),
            message: "weird".into(),
            span: None,
        }
    );
}

#[test]
fn mock_nix_eval_batched_left_side_error() {
    let mock = MockNixEval::default();
    mock.set(
        "bad",
        EvalResult::Err(AssayOutcome::EvalError {
            kind: "throw".into(),
            message: "boom".into(),
            span: None,
        }),
    );
    mock.set("1", EvalResult::Ok(json!(1)));
    assert!(matches!(
        mock.eval_json("[ (bad) (1) ]"),
        EvalResult::Err(_)
    ));
}

#[test]
fn laws_associativity_exercises_object_wrap_branch() {
    assert_eq!(law_merge_associativity(42), AssayOutcome::Pass);
    assert_eq!(
        run_law_by_name("merge_associativity", 99),
        AssayOutcome::Pass
    );
}

#[test]
fn optics_scalar_has_attrs_via_traversal() {
    let scalar = json!(42);
    assert!(!value_has_attrs_via_traversal(&scalar, &["a".into()]));
    let mut keys = Vec::new();
    fold_object_keys(&json!(null), |k| keys.push(k.to_string()));
    assert!(keys.is_empty());
}

#[test]
fn prop_gen_and_shrink_branches() {
    let mut rng = Gen::new(1);
    assert_eq!(rng.gen_u32(1), 0);
    assert_eq!(rng.gen_string(0), "");

    let mut kinds = std::collections::HashSet::new();
    for seed in 0..64u64 {
        let mut g = Gen::new(seed);
        for _ in 0..12 {
            match g.gen_json(1) {
                Value::Null => {
                    kinds.insert("null");
                }
                Value::Bool(_) => {
                    kinds.insert("bool");
                }
                Value::Number(_) => {
                    kinds.insert("num");
                }
                Value::String(_) => {
                    kinds.insert("str");
                }
                Value::Array(_) => {
                    kinds.insert("arr");
                }
                Value::Object(_) => {
                    kinds.insert("obj");
                }
            }
        }
    }
    assert!(kinds.len() >= 4);
    assert_eq!(
        run_prop_by_name("merge_idempotent", 3, 4),
        AssayOutcome::Pass
    );
}

#[test]
fn diff_special_path_and_array_only_changes() {
    let left = json!({"key-with-dash": 1, "plain": "hi"});
    let right = json!({"key-with-dash": 2, "plain": "bye"});
    let diff = structural_diff(&left, &right);
    assert!(diff.contains("$[\"key-with-dash\"]") || diff.contains("key-with-dash"));
    assert!(diff.contains("~ $.plain:"));

    let add_only = structural_diff(&json!([]), &json!([1]));
    assert!(add_only.contains("+ $[0]:"));
    let remove_only = structural_diff(&json!([1]), &json!([]));
    assert!(remove_only.contains("- $[0]:"));
}

#[test]
fn discover_assay_json_and_unknown_single_file() {
    assert_eq!(
        suite_kind(PathBuf::from("x.assay.json").as_path()),
        Some(SuiteKind::AssayNix)
    );
    let unknown = std::env::temp_dir().join(format!("assay_unknown_{}", std::process::id()));
    std::fs::write(&unknown, "x").unwrap();
    let found = discover_suites(&unknown).expect("discover");
    assert!(found.is_empty());
    let _ = std::fs::remove_file(unknown);
}

#[test]
fn parse_assay_suite_error_paths() {
    assert!(parse_assay_suite(&json!([])).is_err());
    assert!(parse_assay_suite(&json!({"name": "t"})).is_err());
}

#[test]
fn schema_value_mode_roundtrip() {
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

#[test]
fn run_suite_blocking_update_snapshots_and_summarize() {
    let dir = std::env::temp_dir().join(format!("assay_run_blk_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join("suite.json");
    std::fs::write(&path, r#"{"ok":{"expr":"1","expected":"1"}}"#).unwrap();
    let mut built = build_env(mock_providers()).expect("env");
    built.insert::<Cap<NixEvaluatorKey>>(Arc::new(MockNixEval::default()) as _);
    built.insert::<Cap<NixWorkerPoolKey>>(Arc::new(MockWorkerPool::new(2)) as _);
    let env = AssayEnv::from_env(built);
    let report = run_suite_blocking(
        &path,
        &RunOptions {
            update_snapshots: true,
            batch_eval: false,
            case_timeout_ms: None,
            ..RunOptions::default()
        },
        env,
    )
    .expect("run");
    assert_eq!(report.outcomes.len(), 1);
    let summary = summarize(&report);
    assert_eq!(summary.total, 1);
    assert_eq!(summary.passed, 1);
    let _ = std::fs::remove_dir_all(dir);
}

#[test]
fn summarize_exits_all_buckets() {
    let outcomes = vec![
        ("pass".into(), Exit::succeed(CaseVerdict::Pass)),
        (
            "fail".into(),
            Exit::succeed(CaseVerdict::AssertFail {
                claim: "eq".into(),
                left: None,
                right: None,
                diff: "d".into(),
            }),
        ),
        (
            "err".into(),
            Exit::fail(InfraError::Timeout {
                case: "slow".into(),
                limit_ms: 1,
            }),
        ),
        (
            "cx".into(),
            Exit::succeed(CaseVerdict::Counterexample {
                seed: 1,
                shrunk: json!(null),
            }),
        ),
        (
            "snap".into(),
            Exit::succeed(CaseVerdict::SnapshotMismatch {
                path: "p".into(),
                diff: "d".into(),
            }),
        ),
    ];
    let s = summarize_exits(&outcomes);
    assert_eq!(s.total, 5);
    assert_eq!(s.passed, 1);
    assert_eq!(s.failed, 3);
    assert_eq!(s.errored, 1);
}

#[test]
fn eval_live_when_nix_available() {
    if std::process::Command::new("nix")
        .arg("--version")
        .output()
        .is_err()
    {
        return;
    }
    let backend = ProcessNixEval;
    assert!(matches!(backend.eval_json("null"), EvalResult::Ok(_)));
    let thrown = backend.eval_json("builtins.throw \"assay-branch-cov\"");
    assert!(matches!(
        thrown,
        EvalResult::Err(AssayOutcome::EvalError { ref kind, .. }) if kind == "throw"
    ));
    let _ = classify_stderr("error: infinite recursion encountered\n");
}

#[cfg(feature = "optics")]
#[test]
fn optics_traversal_scalar_is_noop() {
    use nixq::object_keys_traversal;
    let scalar = json!(42);
    let keys = object_keys_traversal().to_vec(&scalar);
    assert!(keys.is_empty());
    let renamed = object_keys_traversal().over(scalar.clone(), |k| k);
    assert_eq!(renamed, scalar);
}

#[test]
fn decode_claim_rejects_non_object_root() {
    use crate::schema::decode_claim_json;
    assert!(decode_claim_json(&json!("not-object")).is_err());
}

#[test]
fn normalize_derivation_type_field() {
    use nixq::normalize_value;
    let drv = json!({
        "type": "derivation",
        "outPath": "/nix/store/x",
        "name": "pkg",
        "builder": "ignored",
    });
    assert_eq!(
        normalize_value(&drv),
        json!({"type": "derivation", "outPath": "/nix/store/x", "name": "pkg"})
    );
}

#[test]
fn verdict_outcome_to_exit_fail_and_infra_variants() {
    use crate::verdict::{CaseVerdict, InfraError, exit_to_outcome, outcome_to_exit};
    use id_effect::Exit;
    let fail = outcome_to_exit(AssayOutcome::Fail {
        claim: "eq".into(),
        left: None,
        right: None,
        diff: "d".into(),
    });
    assert!(matches!(
        fail,
        Exit::Success(CaseVerdict::AssertFail { .. })
    ));
    for kind in ["io", "json"] {
        let infra = outcome_to_exit(AssayOutcome::EvalError {
            kind: kind.into(),
            message: "m".into(),
            span: None,
        });
        assert!(matches!(
            infra,
            Exit::Failure(id_effect::Cause::Fail(InfraError::Io(_)))
        ));
    }
    let round = exit_to_outcome(Exit::Failure(id_effect::Cause::Fail(
        InfraError::SuiteLoad("bad suite".into()),
    )));
    assert!(matches!(
        round,
        AssayOutcome::EvalError {
            kind,
            ..
        } if kind == "suite_load"
    ));
}

#[test]
fn schema_decode_expr_mode_and_throws_pattern() {
    use crate::claims::Claim;
    use crate::schema::{decode_claim_json, encode_claim_json};
    let eq = decode_claim_json(&json!({
        "claim": "eq",
        "expr": "1",
        "expected": "1"
    }))
    .unwrap();
    assert!(matches!(eq, Claim::Eq { .. }));
    let throws = decode_claim_json(&json!({
        "claim": "throws",
        "expr": "builtins.throw \"x\"",
        "pattern": "x"
    }))
    .unwrap();
    assert!(matches!(
        throws,
        Claim::Throws {
            pattern: Some(_),
            ..
        }
    ));
    let prop = decode_claim_json(&json!({
        "claim": "prop",
        "name": "gen_int",
        "seed": 1,
        "trials": 3
    }))
    .unwrap();
    assert!(matches!(
        prop,
        Claim::Prop {
            trials: Some(3),
            ..
        }
    ));
    let encoded = encode_claim_json(&prop);
    assert_eq!(encoded["trials"], json!(3));
}

#[test]
fn schema_decode_suite_cases_prefixes_errors() {
    use crate::schema::decode_suite_cases;
    assert!(
        decode_suite_cases(&json!({
            "bad": { "claim": "nope" }
        }))
        .is_err()
    );
}

#[test]
fn force_check_forces_unsupported_backend() {
    use crate::eval::EvalBackend;
    use crate::force::check_forces;
    struct Noop;
    impl EvalBackend for Noop {
        fn eval_json(&self, _expr: &str) -> crate::eval::EvalResult {
            crate::eval::EvalResult::Ok(serde_json::json!(null))
        }
    }
    let outcome = check_forces("null", &["x".into()], &Noop);
    assert!(matches!(outcome, AssayOutcome::Fail { .. }));
}
