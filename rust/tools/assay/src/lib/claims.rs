//! Claim algebra interpreter — `Effect` over [`AssayEnv`] returning [`CaseVerdict`].

use serde_json::Value;

use id_effect::{Cause, Effect, Exit};

use crate::caps::{AssayEnv, NixEvaluatorKey, NixWorkerPoolKey, SnapshotStoreKey};
use crate::eval::{EvalBackend, EvalResult};
use crate::force::check_forces;
use crate::outcome::AssayOutcome;
use crate::snapshot::SnapshotStore;
use crate::verdict::{CaseVerdict, InfraError, outcome_to_exit};
use nixq::{normalize_value, structural_diff, value_contains_subset, value_has_attrs};

/// A single test claim authored in Nix and interpreted by the runner.
#[derive(Debug, Clone, PartialEq)]
pub enum Claim {
    Eq {
        left_expr: String,
        right_expr: String,
    },
    /// Already-evaluated sides from suite JSON (first-class Nix authoring).
    EqValues {
        left: Value,
        right: Value,
    },
    Throws {
        expr: String,
        pattern: Option<String>,
    },
    Subset {
        expr: String,
        expected_subset: Value,
    },
    SubsetValues {
        actual: Value,
        expected_subset: Value,
    },
    HasAttrs {
        expr: String,
        attrs: Vec<String>,
    },
    HasAttrsValues {
        actual: Value,
        attrs: Vec<String>,
    },
    Snapshot {
        name: String,
        expr: String,
    },
    Forces {
        expr: String,
        paths: Vec<String>,
    },
    Module {
        imports_expr: String,
        args_expr: String,
        expect: Value,
    },
    /// Run a built-in algebraic law by name.
    Law {
        name: String,
        seed: u64,
    },
    /// Run a built-in property check by name.
    Prop {
        name: String,
        seed: u64,
        trials: Option<u32>,
    },
}

/// Interpret `claim` using capabilities from [`AssayEnv`].
pub fn interpret_claim(claim: Claim) -> Effect<CaseVerdict, InfraError, AssayEnv> {
    Effect::new(move |env| {
        let pool = id_effect::Needs::<NixWorkerPoolKey>::need(env);
        let _slot = pool.acquire()?;
        let eval = id_effect::Needs::<NixEvaluatorKey>::need(env);
        let store = id_effect::Needs::<SnapshotStoreKey>::need(env);
        interpret_claim_with(eval.as_ref(), store, &claim)
    })
}

pub(crate) fn interpret_claim_with(
    eval: &dyn EvalBackend,
    store: &SnapshotStore,
    claim: &Claim,
) -> Result<CaseVerdict, InfraError> {
    let outcome = match claim {
        Claim::Eq {
            left_expr,
            right_expr,
        } => interpret_eq(left_expr, right_expr, eval),
        Claim::EqValues { left, right } => interpret_eq_values(left, right),
        Claim::Throws { expr, pattern } => interpret_throws(expr, pattern.as_deref(), eval),
        Claim::Subset {
            expr,
            expected_subset,
        } => interpret_subset(expr, expected_subset, eval),
        Claim::SubsetValues {
            actual,
            expected_subset,
        } => interpret_subset_values(actual, expected_subset),
        Claim::HasAttrs { expr, attrs } => interpret_has_attrs(expr, attrs, eval),
        Claim::HasAttrsValues { actual, attrs } => interpret_has_attrs_values(actual, attrs),
        Claim::Snapshot { name, expr } => interpret_snapshot(name, expr, eval, store),
        Claim::Forces { expr, paths } => check_forces(expr, paths, eval),
        Claim::Module {
            imports_expr,
            args_expr,
            expect,
        } => interpret_module(imports_expr, args_expr, expect, eval),
        Claim::Law { name, seed } => crate::laws::run_law_by_name(name, *seed),
        Claim::Prop { name, seed, trials } => {
            crate::prop::run_prop_by_name(name, *seed, trials.unwrap_or(128))
        }
    };
    outcome_to_result(outcome)
}

fn outcome_to_result(outcome: AssayOutcome) -> Result<CaseVerdict, InfraError> {
    match outcome_to_exit(outcome) {
        Exit::Success(verdict) => Ok(verdict),
        Exit::Failure(cause) => Err(cause_to_infra(cause)),
    }
}

fn cause_to_infra(cause: Cause<InfraError>) -> InfraError {
    match cause {
        Cause::Fail(err) => err,
        Cause::Die(msg) => InfraError::Worker(msg),
        Cause::Interrupt(id) => InfraError::Worker(format!("interrupted fiber {id:?}")),
        Cause::Both(left, _) => cause_to_infra(*left),
        Cause::Then(_, right) => cause_to_infra(*right),
    }
}

fn interpret_eq(left_expr: &str, right_expr: &str, eval: &dyn EvalBackend) -> AssayOutcome {
    // One nix process for both sides — process spawn dominates tiny exprs.
    let pair_expr = format!("[({left_expr}) ({right_expr})]");
    let (left, right) = match eval.eval_json(&pair_expr) {
        EvalResult::Ok(Value::Array(arr)) if arr.len() == 2 => {
            (normalize_value(&arr[0]), normalize_value(&arr[1]))
        }
        EvalResult::Ok(other) => {
            return AssayOutcome::EvalError {
                kind: "eq_pair".into(),
                message: format!("eq pair eval expected 2-element list, got {other}"),
                span: None,
            };
        }
        EvalResult::Err(out) => return out,
    };
    compare_eq(left, right)
}

fn interpret_eq_values(left: &Value, right: &Value) -> AssayOutcome {
    compare_eq(normalize_value(left), normalize_value(right))
}

fn compare_eq(left: Value, right: Value) -> AssayOutcome {
    if left == right {
        AssayOutcome::Pass
    } else {
        AssayOutcome::Fail {
            claim: "eq".into(),
            left: Some(left.clone()),
            right: Some(right.clone()),
            diff: structural_diff(&left, &right),
        }
    }
}

fn interpret_throws(expr: &str, pattern: Option<&str>, eval: &dyn EvalBackend) -> AssayOutcome {
    match eval.eval_json(expr) {
        EvalResult::Ok(value) => AssayOutcome::Fail {
            claim: "throws".into(),
            left: Some(value),
            right: None,
            diff: "expression evaluated successfully; expected throw".into(),
        },
        EvalResult::Err(out) => {
            if !is_throw_outcome(&out) {
                return out;
            }
            if let Some(pat) = pattern {
                let message = throw_message(&out);
                if message.contains(pat) {
                    AssayOutcome::Pass
                } else {
                    AssayOutcome::Fail {
                        claim: "throws".into(),
                        left: None,
                        right: None,
                        diff: format!("throw message {message:?} does not contain pattern {pat:?}"),
                    }
                }
            } else {
                AssayOutcome::Pass
            }
        }
    }
}

pub fn build_module_eval_expr(imports_expr: &str, args_expr: &str) -> String {
    format!(
        "let lib = (import <nixpkgs> {{}}).lib; eval = lib.evalModules {{ modules = {imports_expr}; specialArgs = {args_expr}; }}; in eval.config"
    )
}

fn interpret_module(
    imports_expr: &str,
    args_expr: &str,
    expect: &Value,
    eval: &dyn EvalBackend,
) -> AssayOutcome {
    let expr = build_module_eval_expr(imports_expr, args_expr);
    let actual = match eval.eval_json(&expr) {
        EvalResult::Ok(v) => v,
        EvalResult::Err(out) => return out,
    };
    if value_contains_subset(&actual, expect) {
        AssayOutcome::Pass
    } else {
        AssayOutcome::Fail {
            claim: "module".into(),
            left: Some(actual.clone()),
            right: Some(expect.clone()),
            diff: structural_diff(&actual, expect),
        }
    }
}

fn interpret_subset(expr: &str, expected_subset: &Value, eval: &dyn EvalBackend) -> AssayOutcome {
    let actual = match eval.eval_json(expr) {
        EvalResult::Ok(v) => v,
        EvalResult::Err(out) => return out,
    };
    interpret_subset_values(&actual, expected_subset)
}

fn interpret_subset_values(actual: &Value, expected_subset: &Value) -> AssayOutcome {
    if value_contains_subset(actual, expected_subset) {
        AssayOutcome::Pass
    } else {
        AssayOutcome::Fail {
            claim: "subset".into(),
            left: Some(actual.clone()),
            right: Some(expected_subset.clone()),
            diff: structural_diff(actual, expected_subset),
        }
    }
}

fn interpret_has_attrs(expr: &str, attrs: &[String], eval: &dyn EvalBackend) -> AssayOutcome {
    let value = match eval.eval_json(expr) {
        EvalResult::Ok(v) => v,
        EvalResult::Err(out) => return out,
    };
    interpret_has_attrs_values(&value, attrs)
}

fn interpret_has_attrs_values(value: &Value, attrs: &[String]) -> AssayOutcome {
    if value_has_attrs(value, attrs) {
        AssayOutcome::Pass
    } else {
        AssayOutcome::Fail {
            claim: "hasAttrs".into(),
            left: Some(value.clone()),
            right: None,
            diff: format!("missing attrs among {:?}", attrs),
        }
    }
}

fn interpret_snapshot(
    name: &str,
    expr: &str,
    eval: &dyn EvalBackend,
    store: &SnapshotStore,
) -> AssayOutcome {
    let actual = match eval.eval_json(expr) {
        EvalResult::Ok(v) => normalize_value(&v),
        EvalResult::Err(out) => return out,
    };
    store.assert_match(name, &actual, store.update_snapshots)
}

fn is_throw_outcome(out: &AssayOutcome) -> bool {
    matches!(
        out,
        AssayOutcome::EvalError { .. } | AssayOutcome::Recursion
    )
}

fn throw_message(out: &AssayOutcome) -> String {
    match out {
        AssayOutcome::EvalError { message, .. } => message.clone(),
        AssayOutcome::Recursion => "infinite recursion".into(),
        _ => String::new(),
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use id_effect::{Cap, Exit, FromEnv, build_env, run_test};

    use super::*;
    use crate::caps::{AssayEnv, MockNixEval, NixEvaluatorKey, mock_providers};

    use crate::verdict::CaseVerdict;

    fn run_claim_test<F>(setup: F, claim: Claim) -> Exit<CaseVerdict, InfraError>
    where
        F: FnOnce(&MockNixEval),
    {
        let mock = Arc::new(MockNixEval::default());
        setup(&mock);
        let mut built = build_env(mock_providers()).expect("env");
        built.insert::<Cap<NixEvaluatorKey>>(mock);
        run_test(interpret_claim(claim), AssayEnv::from_env(built))
    }

    #[test]
    fn eq_passes_when_normalized_values_match() {
        let claim = Claim::Eq {
            left_expr: "a".into(),
            right_expr: "b".into(),
        };
        let exit = run_claim_test(
            |eval| {
                eval.set("a", EvalResult::Ok(serde_json::json!({"x": 1})));
                eval.set("b", EvalResult::Ok(serde_json::json!({"x": 1})));
            },
            claim,
        );
        assert!(matches!(exit, Exit::Success(CaseVerdict::Pass)));
    }

    #[test]
    fn eq_fails_with_diff_when_values_differ() {
        let claim = Claim::Eq {
            left_expr: "a".into(),
            right_expr: "b".into(),
        };
        let exit = run_claim_test(
            |eval| {
                eval.set("a", EvalResult::Ok(serde_json::json!({"x": 1})));
                eval.set("b", EvalResult::Ok(serde_json::json!({"x": 2})));
            },
            claim,
        );
        assert!(matches!(
            exit,
            Exit::Success(CaseVerdict::AssertFail { .. })
        ));
    }

    #[test]
    fn throws_passes_on_eval_error_without_pattern() {
        let claim = Claim::Throws {
            expr: "bad".into(),
            pattern: None,
        };
        let exit = run_claim_test(
            |eval| {
                eval.set(
                    "bad",
                    EvalResult::Err(AssayOutcome::EvalError {
                        kind: "type".into(),
                        message: "boom".into(),
                        span: None,
                    }),
                );
            },
            claim,
        );
        assert!(matches!(exit, Exit::Success(CaseVerdict::Pass)));
    }

    #[test]
    fn throws_fails_when_expression_succeeds() {
        let claim = Claim::Throws {
            expr: "ok".into(),
            pattern: None,
        };
        let exit = run_claim_test(
            |eval| eval.set("ok", EvalResult::Ok(serde_json::json!(1))),
            claim,
        );
        assert!(matches!(
            exit,
            Exit::Success(CaseVerdict::AssertFail { .. })
        ));
    }

    #[test]
    fn throws_pattern_must_match_message() {
        let pass = Claim::Throws {
            expr: "bad".into(),
            pattern: Some("foo".into()),
        };
        let pass_exit = run_claim_test(
            |eval| {
                eval.set(
                    "bad",
                    EvalResult::Err(AssayOutcome::EvalError {
                        kind: "type".into(),
                        message: "undefined variable foo".into(),
                        span: None,
                    }),
                );
            },
            pass,
        );
        assert!(matches!(pass_exit, Exit::Success(CaseVerdict::Pass)));

        let fail = Claim::Throws {
            expr: "bad".into(),
            pattern: Some("bar".into()),
        };
        let fail_exit = run_claim_test(
            |eval| {
                eval.set(
                    "bad",
                    EvalResult::Err(AssayOutcome::EvalError {
                        kind: "type".into(),
                        message: "undefined variable foo".into(),
                        span: None,
                    }),
                );
            },
            fail,
        );
        assert!(matches!(
            fail_exit,
            Exit::Success(CaseVerdict::AssertFail { .. })
        ));
    }

    #[test]
    fn subset_requires_recursive_object_containment() {
        let pass = Claim::Subset {
            expr: "v".into(),
            expected_subset: serde_json::json!({"a": {"b": 1}}),
        };
        let pass_exit = run_claim_test(
            |eval| {
                eval.set(
                    "v",
                    EvalResult::Ok(serde_json::json!({"a": {"b": 1}, "c": 2})),
                )
            },
            pass,
        );
        assert!(matches!(pass_exit, Exit::Success(CaseVerdict::Pass)));

        let fail = Claim::Subset {
            expr: "v".into(),
            expected_subset: serde_json::json!({"a": {"b": 9}}),
        };
        let fail_exit = run_claim_test(
            |eval| {
                eval.set(
                    "v",
                    EvalResult::Ok(serde_json::json!({"a": {"b": 1}, "c": 2})),
                )
            },
            fail,
        );
        assert!(matches!(
            fail_exit,
            Exit::Success(CaseVerdict::AssertFail { .. })
        ));
    }

    #[test]
    fn has_attrs_requires_object_keys() {
        let pass = Claim::HasAttrs {
            expr: "v".into(),
            attrs: vec!["a".into(), "b".into()],
        };
        let pass_exit = run_claim_test(
            |eval| eval.set("v", EvalResult::Ok(serde_json::json!({"a": 1, "b": 2}))),
            pass,
        );
        assert!(matches!(pass_exit, Exit::Success(CaseVerdict::Pass)));

        let fail = Claim::HasAttrs {
            expr: "v".into(),
            attrs: vec!["z".into()],
        };
        let fail_exit = run_claim_test(
            |eval| eval.set("v", EvalResult::Ok(serde_json::json!({"a": 1, "b": 2}))),
            fail,
        );
        assert!(matches!(
            fail_exit,
            Exit::Success(CaseVerdict::AssertFail { .. })
        ));
    }

    #[test]
    fn snapshot_missing_golden_is_snapshot_mismatch() {
        let claim = Claim::Snapshot {
            name: "__assay_no_such_golden__".into(),
            expr: "v".into(),
        };
        let exit = run_claim_test(
            |eval| eval.set("v", EvalResult::Ok(serde_json::json!({"x": 1}))),
            claim,
        );
        assert!(matches!(
            exit,
            Exit::Success(CaseVerdict::SnapshotMismatch { .. })
        ));
    }

    #[test]
    fn forces_delegates_to_force_module_and_fails() {
        let claim = Claim::Forces {
            expr: "x".into(),
            paths: vec!["a".into()],
        };
        let exit = run_claim_test(|_eval| {}, claim);
        assert!(matches!(
            exit,
            Exit::Success(CaseVerdict::AssertFail { .. })
        ));
    }

    #[test]
    fn module_passes_when_config_contains_expect_subset() {
        let imports = "[ ]";
        let args = "{}";
        let expr = build_module_eval_expr(imports, args);
        let claim = Claim::Module {
            imports_expr: imports.into(),
            args_expr: args.into(),
            expect: serde_json::json!({ "assay": { "tiny": { "message": "hello" } } }),
        };
        let exit = run_claim_test(
            |eval| {
                eval.set(
                    &expr,
                    EvalResult::Ok(serde_json::json!({
                        "assay": { "tiny": { "enable": true, "message": "hello" } },
                        "other": "ignored"
                    })),
                );
            },
            claim,
        );
        assert!(matches!(exit, Exit::Success(CaseVerdict::Pass)));
    }

    #[test]
    fn module_fails_when_config_missing_expect_subset() {
        let imports = "[ ]";
        let args = "{}";
        let expr = build_module_eval_expr(imports, args);
        let claim = Claim::Module {
            imports_expr: imports.into(),
            args_expr: args.into(),
            expect: serde_json::json!({ "assay": { "tiny": { "message": "hello" } } }),
        };
        let exit = run_claim_test(
            |eval| {
                eval.set(
                    &expr,
                    EvalResult::Ok(
                        serde_json::json!({ "assay": { "tiny": { "message": "nope" } } }),
                    ),
                );
            },
            claim,
        );
        assert!(matches!(
            exit,
            Exit::Success(CaseVerdict::AssertFail { .. })
        ));
    }

    #[test]
    fn module_propagates_eval_error() {
        let imports = "[ ]";
        let args = "{}";
        let expr = build_module_eval_expr(imports, args);
        let claim = Claim::Module {
            imports_expr: imports.into(),
            args_expr: args.into(),
            expect: serde_json::json!({}),
        };
        let exit = run_claim_test(
            |eval| {
                eval.set(
                    &expr,
                    EvalResult::Err(AssayOutcome::EvalError {
                        kind: "throw".into(),
                        message: "module eval failed".into(),
                        span: None,
                    }),
                );
            },
            claim,
        );
        assert!(matches!(exit, Exit::Success(CaseVerdict::EvalThrow { .. })));
    }
    #[test]
    fn eq_values_pass_without_nix() {
        let exit = run_claim_test(
            |_eval| {},
            Claim::EqValues {
                left: serde_json::json!(1),
                right: serde_json::json!(1),
            },
        );
        assert!(matches!(exit, Exit::Success(CaseVerdict::Pass)));
    }

    #[test]
    fn eq_values_fail_when_different() {
        let exit = run_claim_test(
            |_eval| {},
            Claim::EqValues {
                left: serde_json::json!(1),
                right: serde_json::json!(2),
            },
        );
        assert!(matches!(
            exit,
            Exit::Success(CaseVerdict::AssertFail { .. })
        ));
    }

    #[test]
    fn subset_values_and_hasattrs_values() {
        let sub = run_claim_test(
            |_eval| {},
            Claim::SubsetValues {
                actual: serde_json::json!({"a": 1, "b": 2}),
                expected_subset: serde_json::json!({"a": 1}),
            },
        );
        assert!(matches!(sub, Exit::Success(CaseVerdict::Pass)));

        let has = run_claim_test(
            |_eval| {},
            Claim::HasAttrsValues {
                actual: serde_json::json!({"a": 1}),
                attrs: vec!["a".into()],
            },
        );
        assert!(matches!(has, Exit::Success(CaseVerdict::Pass)));
    }

    #[test]
    fn law_and_prop_claims_run() {
        let law = run_claim_test(
            |_eval| {},
            Claim::Law {
                name: "merge_idempotent".into(),
                seed: 1,
            },
        );
        assert!(matches!(
            law,
            Exit::Success(CaseVerdict::Pass) | Exit::Success(CaseVerdict::AssertFail { .. })
        ));

        let prop = run_claim_test(
            |_eval| {},
            Claim::Prop {
                name: "always_pass".into(),
                seed: 1,
                trials: Some(4),
            },
        );
        assert!(matches!(prop, Exit::Success(CaseVerdict::Pass)));
    }

    #[test]
    fn interpret_eq_bad_pair_length_returns_eq_pair_error() {
        let exit = run_claim_test(
            |eval| {
                eval.set("[(1) (2)]", EvalResult::Ok(serde_json::json!([1])));
            },
            Claim::Eq {
                left_expr: "1".into(),
                right_expr: "2".into(),
            },
        );
        match exit {
            Exit::Success(CaseVerdict::EvalThrow { kind, .. }) => {
                assert_eq!(kind, "eq_pair");
            }
            other => panic!("expected eq_pair eval throw, got {other:?}"),
        }
    }

    #[test]
    fn interpret_throws_propagates_non_throw_eval_error() {
        let exit = run_claim_test(
            |eval| {
                eval.set("expr", EvalResult::Err(AssayOutcome::Timeout));
            },
            Claim::Throws {
                expr: "expr".into(),
                pattern: None,
            },
        );
        assert!(matches!(exit, Exit::Failure(_)));
    }
}
