//! Claim algebra interpreter — maps [`Claim`] values to [`AssayOutcome`] via an [`EvalBackend`].

use std::fs;
use std::path::PathBuf;

use serde_json::Value;

use crate::diff::structural_diff;
use crate::eval::{EvalBackend, EvalResult};
use crate::force::check_forces;
use crate::normalize::normalize_value;
use crate::optics_json::{value_contains_subset, value_has_attrs};
use crate::outcome::AssayOutcome;

/// A single test claim authored in Nix and interpreted by the runner.
#[derive(Debug, Clone, PartialEq)]
pub enum Claim {
    Eq {
        left_expr: String,
        right_expr: String,
    },
    Throws {
        expr: String,
        pattern: Option<String>,
    },
    Subset {
        expr: String,
        expected_subset: Value,
    },
    HasAttrs {
        expr: String,
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

/// Interpret `claim` against `eval`, returning Pass or a structured failure outcome.
pub fn interpret_claim(claim: &Claim, eval: &dyn EvalBackend) -> AssayOutcome {
    match claim {
        Claim::Eq {
            left_expr,
            right_expr,
        } => interpret_eq(left_expr, right_expr, eval),
        Claim::Throws { expr, pattern } => interpret_throws(expr, pattern.as_deref(), eval),
        Claim::Subset {
            expr,
            expected_subset,
        } => interpret_subset(expr, expected_subset, eval),
        Claim::HasAttrs { expr, attrs } => interpret_has_attrs(expr, attrs, eval),
        Claim::Snapshot { name, expr } => interpret_snapshot(name, expr, eval),
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
    }
}

fn interpret_eq(left_expr: &str, right_expr: &str, eval: &dyn EvalBackend) -> AssayOutcome {
    let left = match eval.eval_json(left_expr) {
        EvalResult::Ok(v) => normalize_value(&v),
        EvalResult::Err(out) => return out,
    };
    let right = match eval.eval_json(right_expr) {
        EvalResult::Ok(v) => normalize_value(&v),
        EvalResult::Err(out) => return out,
    };
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

fn interpret_throws(
    expr: &str,
    pattern: Option<&str>,
    eval: &dyn EvalBackend,
) -> AssayOutcome {
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
                        diff: format!(
                            "throw message {message:?} does not contain pattern {pat:?}"
                        ),
                    }
                }
            } else {
                AssayOutcome::Pass
            }
        }
    }
}

fn build_module_eval_expr(imports_expr: &str, args_expr: &str) -> String {
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

fn interpret_subset(
    expr: &str,
    expected_subset: &Value,
    eval: &dyn EvalBackend,
) -> AssayOutcome {
    let actual = match eval.eval_json(expr) {
        EvalResult::Ok(v) => v,
        EvalResult::Err(out) => return out,
    };
    if value_contains_subset(&actual, expected_subset) {
        AssayOutcome::Pass
    } else {
        AssayOutcome::Fail {
            claim: "subset".into(),
            left: Some(actual.clone()),
            right: Some(expected_subset.clone()),
            diff: structural_diff(&actual, expected_subset),
        }
    }
}

fn interpret_has_attrs(expr: &str, attrs: &[String], eval: &dyn EvalBackend) -> AssayOutcome {
    let value = match eval.eval_json(expr) {
        EvalResult::Ok(v) => v,
        EvalResult::Err(out) => return out,
    };
    if value_has_attrs(&value, attrs) {
        AssayOutcome::Pass
    } else {
        AssayOutcome::Fail {
            claim: "hasAttrs".into(),
            left: Some(value),
            right: None,
            diff: format!("missing attrs among {:?}", attrs),
        }
    }
}

fn interpret_snapshot(name: &str, expr: &str, eval: &dyn EvalBackend) -> AssayOutcome {
    let actual = match eval.eval_json(expr) {
        EvalResult::Ok(v) => normalize_value(&v),
        EvalResult::Err(out) => return out,
    };
    let path = golden_path(name);
    let golden_raw = match fs::read_to_string(&path) {
        Ok(s) => s,
        Err(_) => {
            return AssayOutcome::SnapshotMismatch {
                path: path.display().to_string(),
                diff: format!("golden missing at {}", path.display()),
            };
        }
    };
    let expected: Value = match serde_json::from_str(&golden_raw) {
        Ok(v) => normalize_value(&v),
        Err(err) => {
            return AssayOutcome::SnapshotMismatch {
                path: path.display().to_string(),
                diff: format!("invalid golden JSON: {err}"),
            };
        }
    };
    if actual == expected {
        AssayOutcome::Pass
    } else {
        AssayOutcome::SnapshotMismatch {
            path: path.display().to_string(),
            diff: structural_diff(&actual, &expected),
        }
    }
}

fn golden_path(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("testdata/goldens")
        .join(format!("{name}.json"))
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

    use id_effect::{Cap, Effect, Exit, FromEnv, Needs, build_env, run_test};

    use super::*;
    use crate::caps::{AssayEnv, MockNixEval, NixEvaluatorKey, mock_providers};

    fn run_claim_test<F>(setup: F, claim: &Claim) -> AssayOutcome
    where
        F: FnOnce(&MockNixEval),
    {
        let mock = Arc::new(MockNixEval::default());
        setup(&mock);

        let mut built = build_env(mock_providers()).expect("env");
        built.insert::<Cap<NixEvaluatorKey>>(mock);
        let env = AssayEnv::from_env(built);

        let claim = claim.clone();
        let effect: Effect<AssayOutcome, (), AssayEnv> = Effect::new(move |caps| {
            let eval = Needs::<NixEvaluatorKey>::need(caps);
            Ok(interpret_claim(&claim, eval.as_ref()))
        });
        let exit = run_test(effect, env);
        match exit {
            Exit::Success(out) => out,
            other => panic!("expected success exit, got {other:?}"),
        }
    }

    #[test]
    fn eq_passes_when_normalized_values_match() {
        let claim = Claim::Eq {
            left_expr: "a".into(),
            right_expr: "b".into(),
        };
        let out = run_claim_test(
            |eval| {
                eval.set("a", EvalResult::Ok(serde_json::json!({"x": 1})));
                eval.set("b", EvalResult::Ok(serde_json::json!({"x": 1})));
            },
            &claim,
        );
        assert_eq!(out, AssayOutcome::Pass);
    }

    #[test]
    fn eq_fails_with_diff_when_values_differ() {
        let claim = Claim::Eq {
            left_expr: "a".into(),
            right_expr: "b".into(),
        };
        let out = run_claim_test(
            |eval| {
                eval.set("a", EvalResult::Ok(serde_json::json!({"x": 1})));
                eval.set("b", EvalResult::Ok(serde_json::json!({"x": 2})));
            },
            &claim,
        );
        assert!(matches!(out, AssayOutcome::Fail { claim, .. } if claim == "eq"));
    }

    #[test]
    fn throws_passes_on_eval_error_without_pattern() {
        let claim = Claim::Throws {
            expr: "bad".into(),
            pattern: None,
        };
        let out = run_claim_test(
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
            &claim,
        );
        assert_eq!(out, AssayOutcome::Pass);
    }

    #[test]
    fn throws_fails_when_expression_succeeds() {
        let claim = Claim::Throws {
            expr: "ok".into(),
            pattern: None,
        };
        let out = run_claim_test(
            |eval| eval.set("ok", EvalResult::Ok(serde_json::json!(1))),
            &claim,
        );
        assert!(matches!(out, AssayOutcome::Fail { claim, .. } if claim == "throws"));
    }

    #[test]
    fn throws_pattern_must_match_message() {
        let pass = Claim::Throws {
            expr: "bad".into(),
            pattern: Some("foo".into()),
        };
        let pass_out = run_claim_test(
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
            &pass,
        );
        assert_eq!(pass_out, AssayOutcome::Pass);

        let fail = Claim::Throws {
            expr: "bad".into(),
            pattern: Some("bar".into()),
        };
        let fail_out = run_claim_test(
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
            &fail,
        );
        assert!(matches!(fail_out, AssayOutcome::Fail { .. }));
    }

    #[test]
    fn subset_requires_recursive_object_containment() {
        let pass = Claim::Subset {
            expr: "v".into(),
            expected_subset: serde_json::json!({"a": {"b": 1}}),
        };
        let pass_out = run_claim_test(
            |eval| eval.set("v", EvalResult::Ok(serde_json::json!({"a": {"b": 1}, "c": 2}))),
            &pass,
        );
        assert_eq!(pass_out, AssayOutcome::Pass);

        let fail = Claim::Subset {
            expr: "v".into(),
            expected_subset: serde_json::json!({"a": {"b": 9}}),
        };
        let fail_out = run_claim_test(
            |eval| eval.set("v", EvalResult::Ok(serde_json::json!({"a": {"b": 1}, "c": 2}))),
            &fail,
        );
        assert!(matches!(fail_out, AssayOutcome::Fail { claim, .. } if claim == "subset"));
    }

    #[test]
    fn has_attrs_requires_object_keys() {
        let pass = Claim::HasAttrs {
            expr: "v".into(),
            attrs: vec!["a".into(), "b".into()],
        };
        let pass_out = run_claim_test(
            |eval| eval.set("v", EvalResult::Ok(serde_json::json!({"a": 1, "b": 2}))),
            &pass,
        );
        assert_eq!(pass_out, AssayOutcome::Pass);

        let fail = Claim::HasAttrs {
            expr: "v".into(),
            attrs: vec!["z".into()],
        };
        let fail_out = run_claim_test(
            |eval| eval.set("v", EvalResult::Ok(serde_json::json!({"a": 1, "b": 2}))),
            &fail,
        );
        assert!(matches!(fail_out, AssayOutcome::Fail { claim, .. } if claim == "hasAttrs"));
    }

    #[test]
    fn snapshot_missing_golden_is_snapshot_mismatch() {
        let claim = Claim::Snapshot {
            name: "__assay_no_such_golden__".into(),
            expr: "v".into(),
        };
        let out = run_claim_test(
            |eval| eval.set("v", EvalResult::Ok(serde_json::json!({"x": 1}))),
            &claim,
        );
        assert!(matches!(out, AssayOutcome::SnapshotMismatch { .. }));
    }

    #[test]
    fn forces_delegates_to_force_module_and_fails() {
        let claim = Claim::Forces {
            expr: "x".into(),
            paths: vec!["a".into()],
        };
        let out = run_claim_test(|_eval| {}, &claim);
        assert!(matches!(out, AssayOutcome::Fail { claim, .. } if claim == "forces"));
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
        let out = run_claim_test(
            |eval| {
                eval.set(
                    &expr,
                    EvalResult::Ok(serde_json::json!({
                        "assay": { "tiny": { "enable": true, "message": "hello" } },
                        "other": "ignored"
                    })),
                );
            },
            &claim,
        );
        assert_eq!(out, AssayOutcome::Pass);
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
        let out = run_claim_test(
            |eval| {
                eval.set(
                    &expr,
                    EvalResult::Ok(serde_json::json!({ "assay": { "tiny": { "message": "nope" } } })),
                );
            },
            &claim,
        );
        assert!(matches!(out, AssayOutcome::Fail { claim, .. } if claim == "module"));
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
        let out = run_claim_test(
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
            &claim,
        );
        assert!(matches!(out, AssayOutcome::EvalError { kind, .. } if kind == "throw"));
    }
}
