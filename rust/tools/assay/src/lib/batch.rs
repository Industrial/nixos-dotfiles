//! Suite-/repo-level batched Nix evaluation via `builtins.tryEval`.
//!
//! Process spawn dominates tiny claim exprs. Batching all batchable claims into
//! one `nix eval` collapses O(cases) processes to O(1) while preserving throw
//! isolation for pattern-matched `throws` (those stay process-isolated).

use serde_json::Value;

use crate::claims::{Claim, interpret_claim_with};
use crate::diff::structural_diff;
use crate::eval::{EvalBackend, EvalResult};
use crate::normalize::normalize_value;
use crate::optics_json::value_contains_subset;
use crate::outcome::AssayOutcome;
use crate::snapshot::SnapshotStore;
use crate::verdict::{CaseVerdict, InfraError, outcome_to_exit};
use id_effect::Exit;

/// Marker embedded in generated Nix so mocks / debuggers can recognize batches.
pub const BATCH_MARKER: &str = "__assayBatch";

/// Whether `claim` can run inside a tryEval mega-batch.
pub fn is_batchable(claim: &Claim) -> bool {
    match claim {
        // Eq/subset/hasAttrs/snapshot — values are JSON-serializable on the happy path.
        Claim::Eq { .. } | Claim::Subset { .. } | Claim::HasAttrs { .. } | Claim::Snapshot { .. } => {
            true
        }
        // All throws stay process-isolated: Nix 2.31+ `tryEval` catches `throw`/`assert`
        // but NOT primop type errors (e.g. `builtins.add "x" 1`), and pattern throws need stderr.
        Claim::EqValues { .. }
        | Claim::SubsetValues { .. }
        | Claim::HasAttrsValues { .. }
        | Claim::Throws { .. }
        | Claim::Forces { .. }
        | Claim::Module { .. }
        | Claim::Law { .. }
        | Claim::Prop { .. } => false,
    }
}

#[derive(Debug, Clone)]
enum BatchKind {
    Eq,
    Subset { expected: Value },
    HasAttrs { attrs: Vec<String> },
    Snapshot { snap_name: String },
}

#[derive(Debug, Clone)]
struct BatchSlot {
    name: String,
    kind: BatchKind,
    primary_expr: String,
    secondary_expr: Option<String>,
}

/// Partition cases into batchable slots and claims that must stay isolated.
pub fn partition_cases(
    cases: Vec<(String, Claim)>,
) -> (Vec<(String, Claim)>, Vec<(String, Claim)>) {
    let mut batchable = Vec::new();
    let mut isolated = Vec::new();
    for (name, claim) in cases {
        if is_batchable(&claim) {
            batchable.push((name, claim));
        } else {
            isolated.push((name, claim));
        }
    }
    (batchable, isolated)
}

fn to_slot(name: String, claim: Claim) -> BatchSlot {
    match claim {
        Claim::Eq {
            left_expr,
            right_expr,
        } => BatchSlot {
            name,
            kind: BatchKind::Eq,
            primary_expr: left_expr,
            secondary_expr: Some(right_expr),
        },
        Claim::Subset {
            expr,
            expected_subset,
        } => BatchSlot {
            name,
            kind: BatchKind::Subset {
                expected: expected_subset,
            },
            primary_expr: expr,
            secondary_expr: None,
        },
        Claim::HasAttrs { expr, attrs } => BatchSlot {
            name,
            kind: BatchKind::HasAttrs { attrs },
            primary_expr: expr,
            secondary_expr: None,
        },
        Claim::Snapshot {
            name: snap_name,
            expr,
        } => BatchSlot {
            name,
            kind: BatchKind::Snapshot { snap_name },
            primary_expr: expr,
            secondary_expr: None,
        },
        other => unreachable!("non-batchable claim in to_slot: {other:?}"),
    }
}

fn wrap_nix(expr: &str) -> String {
    // Raw embed inside a generated .nix file (not `--expr`): multiline/quotes work.
    // tryEval catches `throw`/`assert`. Avoid builtins.toJSON: it rejects strings that
    // refer to store paths (IFC), while `nix eval --impure --json` can serialize them.
    // Primop type errors still abort the mega-batch → per-claim fallback in `run_batch`.
    format!(
        "(let r = builtins.tryEval ({expr}); in {{ ok = r.success; value = if r.success then r.value else null; }})"
    )
}

/// Project attr names only — avoids serializing huge module configs in the batch.
fn wrap_nix_attr_names(expr: &str) -> String {
    format!(
        "(let r = builtins.tryEval ({expr}); in if r.success then {{ ok = true; keys = builtins.attrNames r.value; }} else {{ ok = false; keys = []; }})"
    )
}

/// Build a single Nix expression that evaluates every batchable claim.
fn build_batch_expr(cases: &[(String, Claim)]) -> (String, Vec<BatchSlot>) {
    let slots: Vec<BatchSlot> = cases
        .iter()
        .cloned()
        .map(|(n, c)| to_slot(n, c))
        .collect();

    let mut items = Vec::with_capacity(slots.len());
    for (idx, slot) in slots.iter().enumerate() {
        let name_lit = nix_string_literal(&slot.name);
        let kind_lit = match &slot.kind {
            BatchKind::Eq => "eq",
            BatchKind::Subset { .. } => "subset",
            BatchKind::HasAttrs { .. } => "hasAttrs",
            BatchKind::Snapshot { .. } => "snapshot",
        };
        let body = match &slot.kind {
            BatchKind::Eq => {
                let left = wrap_nix(&slot.primary_expr);
                let right = wrap_nix(slot.secondary_expr.as_deref().unwrap());
                format!(
                    "{{ i = {idx}; name = {name_lit}; kind = \"{kind_lit}\"; left = {left}; right = {right}; }}"
                )
            }
            BatchKind::HasAttrs { .. } => {
                let primary = wrap_nix_attr_names(&slot.primary_expr);
                format!(
                    "{{ i = {idx}; name = {name_lit}; kind = \"{kind_lit}\"; primary = {primary}; }}"
                )
            }
            BatchKind::Subset { .. } | BatchKind::Snapshot { .. } => {
                let primary = wrap_nix(&slot.primary_expr);
                format!(
                    "{{ i = {idx}; name = {name_lit}; kind = \"{kind_lit}\"; primary = {primary}; }}"
                )
            }
        };
        items.push(body);
    }

    let expr = format!(
        "({{ {BATCH_MARKER} = true; results = [\n{}\n]; }})",
        items.join("\n")
    );
    (expr, slots)
}


fn nix_string_literal(s: &str) -> String {
    let escaped = s
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('$', "\\$");
    format!("\"{escaped}\"")
}

fn decode_try(node: &Value) -> Result<Option<Value>, AssayOutcome> {
    let obj = node.as_object().ok_or_else(|| AssayOutcome::EvalError {
        kind: "batch".into(),
        message: format!("tryEval wrapper not an object: {node}"),
        span: None,
    })?;
    match obj.get("ok").and_then(Value::as_bool) {
        Some(true) => Ok(Some(normalize_value(
            obj.get("value").unwrap_or(&Value::Null),
        ))),
        Some(false) => Ok(None),
        None => Err(AssayOutcome::EvalError {
            kind: "batch".into(),
            message: format!("tryEval wrapper missing ok: {node}"),
            span: None,
        }),
    }
}

fn slot_outcome(slot: &BatchSlot, row: &Value, store: &SnapshotStore) -> AssayOutcome {
    let kind = row.get("kind").and_then(Value::as_str).unwrap_or("");
    match (&slot.kind, kind) {
        (BatchKind::Eq, "eq") => {
            let left = match decode_try(row.get("left").unwrap_or(&Value::Null)) {
                Ok(Some(v)) => v,
                Ok(None) => {
                    return AssayOutcome::EvalError {
                        kind: "throw".into(),
                        message: "left side of eq failed to evaluate".into(),
                        span: None,
                    };
                }
                Err(e) => return e,
            };
            let right = match decode_try(row.get("right").unwrap_or(&Value::Null)) {
                Ok(Some(v)) => v,
                Ok(None) => {
                    return AssayOutcome::EvalError {
                        kind: "throw".into(),
                        message: "right side of eq failed to evaluate".into(),
                        span: None,
                    };
                }
                Err(e) => return e,
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
        (BatchKind::Subset { expected }, "subset") => {
            match decode_try(row.get("primary").unwrap_or(&Value::Null)) {
                Ok(Some(actual)) => {
                    if value_contains_subset(&actual, expected) {
                        AssayOutcome::Pass
                    } else {
                        AssayOutcome::Fail {
                            claim: "subset".into(),
                            left: Some(actual.clone()),
                            right: Some(expected.clone()),
                            diff: structural_diff(&actual, expected),
                        }
                    }
                }
                Ok(None) => AssayOutcome::EvalError {
                    kind: "throw".into(),
                    message: "subset expr failed to evaluate".into(),
                    span: None,
                },
                Err(e) => e,
            }
        }
        (BatchKind::HasAttrs { attrs }, "hasAttrs") => {
            let primary = row.get("primary").unwrap_or(&Value::Null);
            let ok = primary.get("ok").and_then(Value::as_bool);
            match ok {
                Some(true) => {
                    let keys: Vec<String> = primary
                        .get("keys")
                        .and_then(Value::as_array)
                        .map(|arr| {
                            arr.iter()
                                .filter_map(|v| v.as_str().map(str::to_owned))
                                .collect()
                        })
                        .unwrap_or_default();
                    let missing: Vec<&str> = attrs
                        .iter()
                        .filter(|a| !keys.iter().any(|k| k == *a))
                        .map(String::as_str)
                        .collect();
                    if missing.is_empty() {
                        AssayOutcome::Pass
                    } else {
                        AssayOutcome::Fail {
                            claim: "hasAttrs".into(),
                            left: Some(Value::Array(
                                keys.into_iter().map(Value::String).collect(),
                            )),
                            right: None,
                            diff: format!("missing attrs: {missing:?}"),
                        }
                    }
                }
                Some(false) => AssayOutcome::EvalError {
                    kind: "throw".into(),
                    message: "hasAttrs expr failed to evaluate".into(),
                    span: None,
                },
                None => AssayOutcome::EvalError {
                    kind: "batch".into(),
                    message: format!("hasAttrs wrapper missing ok: {primary}"),
                    span: None,
                },
            }
        }
        (BatchKind::Snapshot { snap_name }, "snapshot") => {
            match decode_try(row.get("primary").unwrap_or(&Value::Null)) {
                Ok(Some(actual)) => {
                    store.assert_match(snap_name, &actual, store.update_snapshots)
                }
                Ok(None) => AssayOutcome::EvalError {
                    kind: "throw".into(),
                    message: "snapshot expr failed to evaluate".into(),
                    span: None,
                },
                Err(e) => e,
            }
        }
        _ => AssayOutcome::EvalError {
            kind: "batch".into(),
            message: format!(
                "batch row kind mismatch for {}: slot={:?} row={kind}",
                slot.name, slot.kind
            ),
            span: None,
        },
    }
}


#[cfg(test)]
thread_local! {
    pub(crate) static FORCE_BATCH_JSON_EVAL: std::cell::Cell<bool> =
        const { std::cell::Cell::new(false) };
    /// When set, `eval_batch_expr` uses this instead of `nix_eval_file` (file path only).
    pub(crate) static BATCH_NIX_FILE_EVAL: std::cell::Cell<Option<AssayOutcome>> =
        const { std::cell::Cell::new(None) };
}

fn eval_batch_expr(eval: &dyn EvalBackend, expr: &str) -> Result<Value, InfraError> {
    #[cfg(test)]
    if FORCE_BATCH_JSON_EVAL.get() {
        return match eval.eval_json(expr) {
            EvalResult::Ok(v) => Ok(v),
            EvalResult::Err(AssayOutcome::EvalError { message, .. }) => {
                Err(InfraError::Worker(format!("batch eval failed: {message}")))
            }
            EvalResult::Err(other) => Err(InfraError::Worker(format!(
                "batch eval failed: {other:?}"
            ))),
        };
    }

    // Prefer a temp file: mega-batches easily exceed exec ARG_MAX via `--expr`.
    let dir = std::env::temp_dir().join(format!(
        "assay-batch-{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_nanos())
            .unwrap_or(0)
    ));
    std::fs::create_dir_all(&dir).map_err(|e| InfraError::Io(e.to_string()))?;
    let path = dir.join("batch.nix");
    std::fs::write(&path, expr).map_err(|e| InfraError::Io(e.to_string()))?;
    let result = {
        #[cfg(test)]
        {
            if let Some(forced) = BATCH_NIX_FILE_EVAL.take() {
                Err(forced)
            } else {
                crate::eval::nix_eval_file(&path)
            }
        }
        #[cfg(not(test))]
        {
            crate::eval::nix_eval_file(&path)
        }
    };
    let _ = std::fs::remove_dir_all(&dir);
    match result {
        Ok(v) => Ok(v),
        Err(AssayOutcome::EvalError { message, .. }) => match eval.eval_json(expr) {
            EvalResult::Ok(v) => Ok(v),
            EvalResult::Err(AssayOutcome::EvalError { message: m2, .. }) => Err(
                InfraError::Worker(format!("batch eval failed: {message}; fallback: {m2}")),
            ),
            EvalResult::Err(other) => Err(InfraError::Worker(format!(
                "batch eval failed: {message}; fallback: {other:?}"
            ))),
        },
        Err(other) => match eval.eval_json(expr) {
            EvalResult::Ok(v) => Ok(v),
            EvalResult::Err(_) => Err(InfraError::Worker(format!("batch eval failed: {other:?}"))),
        },
    }
}


fn run_batch_fallback(
    cases: &[(String, Claim)],
    eval: &dyn EvalBackend,
    store: &SnapshotStore,
    batch_err: InfraError,
) -> Result<Vec<(String, Exit<CaseVerdict, InfraError>)>, InfraError> {
    let _ = batch_err; // reserved for future tracing
    let mut out = Vec::with_capacity(cases.len());
    for (name, claim) in cases {
        // Prefer the isolated interpreter (same path as `--no-batch`) so IFC /
        // store-path edge cases that break mega-batch still pass per claim.
        match interpret_claim_with(eval, store, claim) {
            Ok(verdict) => out.push((name.clone(), Exit::Success(verdict))),
            Err(e) => out.push((name.clone(), Exit::Failure(id_effect::Cause::Fail(e)))),
        }
    }
    Ok(out)
}

/// Evaluate all batchable claims in one nix process; return verdicts.
pub fn run_batch(
    cases: &[(String, Claim)],
    eval: &dyn EvalBackend,
    store: &SnapshotStore,
) -> Result<Vec<(String, Exit<CaseVerdict, InfraError>)>, InfraError> {
    if cases.is_empty() {
        return Ok(Vec::new());
    }
    let t_build = std::time::Instant::now();
    let (expr, slots) = build_batch_expr(cases);
    if std::env::var_os("ASSAY_TRACE").is_some() {
        eprintln!(
            "assay_trace: build_batch {:.1}ms ({} slots, {} bytes)",
            t_build.elapsed().as_secs_f64() * 1000.0,
            slots.len(),
            expr.len()
        );
    }
    let t_eval = std::time::Instant::now();
    let value = match eval_batch_expr(eval, &expr) {
        Ok(v) => {
            if std::env::var_os("ASSAY_TRACE").is_some() {
                eprintln!(
                    "assay_trace: eval_batch {:.1}ms",
                    t_eval.elapsed().as_secs_f64() * 1000.0
                );
            }
            v
        }
        Err(batch_err) => {
            if std::env::var_os("ASSAY_TRACE").is_some() {
                eprintln!(
                    "assay_trace: eval_batch FAIL {:.1}ms → fallback",
                    t_eval.elapsed().as_secs_f64() * 1000.0
                );
            }
            // Primop type errors escape tryEval on Nix 2.31+ and abort the mega-batch.
            // Fall back to one-process-per-claim so the suite still completes.
            return run_batch_fallback(cases, eval, store, batch_err);
        }
    };

    let results = value
        .get("results")
        .and_then(Value::as_array)
        .ok_or_else(|| {
            InfraError::Worker(format!(
                "batch eval missing results array (marker {BATCH_MARKER})"
            ))
        })?;

    if results.len() != slots.len() {
        return Err(InfraError::Worker(format!(
            "batch result count {} != slot count {}",
            results.len(),
            slots.len()
        )));
    }

    let mut out = Vec::with_capacity(slots.len());
    for (slot, row) in slots.iter().zip(results.iter()) {
        let outcome = slot_outcome(slot, row, store);
        out.push((slot.name.clone(), outcome_to_exit(outcome)));
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::eval::ProcessNixEval;
    use crate::snapshot::SnapshotStore;
    use std::path::PathBuf;

    #[test]
    fn partition_splits_pattern_throws() {
        let cases = vec![
            (
                "a".into(),
                Claim::Eq {
                    left_expr: "1".into(),
                    right_expr: "1".into(),
                },
            ),
            (
                "b".into(),
                Claim::Throws {
                    expr: "builtins.throw \"x\"".into(),
                    pattern: Some("x".into()),
                },
            ),
            (
                "c".into(),
                Claim::Throws {
                    expr: "builtins.throw \"y\"".into(),
                    pattern: None,
                },
            ),
        ];
        let (batch, iso) = partition_cases(cases);
        assert_eq!(batch.len(), 1);
        assert_eq!(iso.len(), 2);
        assert!(iso.iter().any(|(n, _)| n == "b"));
        assert!(iso.iter().any(|(n, _)| n == "c"));
    }

    #[test]
    fn build_batch_expr_contains_marker_and_names() {
        let cases = vec![(
            "add".into(),
            Claim::Eq {
                left_expr: "1 + 1".into(),
                right_expr: "2".into(),
            },
        )];
        let (expr, slots) = build_batch_expr(&cases);
        assert!(expr.contains(BATCH_MARKER));
        assert!(expr.contains("tryEval"));
        assert!(!expr.contains("toJSON"));
        assert!(expr.contains("r.success"));
        assert_eq!(slots.len(), 1);
        assert_eq!(slots[0].name, "add");
    }


    use crate::caps::MockNixEval;
    use serde_json::json;

    struct MockBatchJsonEval {
        inner: MockNixEval,
        results: Value,
    }

    impl EvalBackend for MockBatchJsonEval {
        fn eval_json(&self, expr: &str) -> EvalResult {
            if expr.contains(BATCH_MARKER) {
                return EvalResult::Ok(self.results.clone());
            }
            self.inner.eval_json(expr)
        }
    }

    fn sample_slot(name: &str, kind: BatchKind) -> BatchSlot {
        BatchSlot {
            name: name.into(),
            kind,
            primary_expr: "p".into(),
            secondary_expr: None,
        }
    }

    #[test]
    fn run_batch_empty_returns_empty() {
        let store = SnapshotStore::new(PathBuf::from("/tmp/assay-batch-empty"));
        let outs = run_batch(&[], &MockNixEval::default(), &store).expect("empty");
        assert!(outs.is_empty());
    }

    #[test]
    fn decode_try_ok_and_throw_paths() {
        let ok = decode_try(&json!({"ok": true, "value": 1})).expect("decode");
        assert_eq!(ok, Some(json!(1)));
        let throw = decode_try(&json!({"ok": false})).expect("decode");
        assert_eq!(throw, None);
        assert!(decode_try(&json!("nope")).is_err());
        assert!(decode_try(&json!({})).is_err());
    }

    #[test]
    fn slot_outcome_eq_fail_and_throw_paths() {
        let store = SnapshotStore::new(PathBuf::from("/tmp/assay-slot"));
        let slot = sample_slot("eq", BatchKind::Eq);
        let fail_row = json!({
            "kind": "eq",
            "left": {"ok": true, "value": 1},
            "right": {"ok": true, "value": 2}
        });
        assert!(matches!(slot_outcome(&slot, &fail_row, &store), AssayOutcome::Fail { .. }));

        let left_throw = json!({"kind": "eq", "left": {"ok": false}, "right": {"ok": true, "value": 1}});
        assert!(matches!(slot_outcome(&slot, &left_throw, &store), AssayOutcome::EvalError { .. }));

        let mismatch = json!({"kind": "subset", "primary": {"ok": true, "value": {}}});
        assert!(matches!(slot_outcome(&slot, &mismatch, &store), AssayOutcome::EvalError { .. }));
    }

    #[test]
    fn slot_outcome_subset_hasattrs_snapshot_paths() {
        let store = SnapshotStore::new(PathBuf::from("/tmp/assay-slot2"));
        let subset = sample_slot("s", BatchKind::Subset { expected: json!({"a": 1}) });
        let subset_ok = json!({"kind": "subset", "primary": {"ok": true, "value": {"a": 1, "b": 2}}});
        assert_eq!(slot_outcome(&subset, &subset_ok, &store), AssayOutcome::Pass);

        let subset_fail = json!({"kind": "subset", "primary": {"ok": true, "value": {"a": 9}}});
        assert!(matches!(slot_outcome(&subset, &subset_fail, &store), AssayOutcome::Fail { .. }));

        let has = sample_slot("h", BatchKind::HasAttrs { attrs: vec!["a".into()] });
        let has_ok = json!({"kind": "hasAttrs", "primary": {"ok": true, "keys": ["a"]}});
        assert_eq!(slot_outcome(&has, &has_ok, &store), AssayOutcome::Pass);
        let has_missing = json!({"kind": "hasAttrs", "primary": {"ok": true, "keys": []}});
        assert!(matches!(slot_outcome(&has, &has_missing, &store), AssayOutcome::Fail { .. }));

        let snap = sample_slot("snap", BatchKind::Snapshot { snap_name: "__missing__".into() });
        let snap_row = json!({"kind": "snapshot", "primary": {"ok": true, "value": {"x": 1}}});
        assert!(matches!(slot_outcome(&snap, &snap_row, &store), AssayOutcome::SnapshotMismatch { .. }));
    }

    #[test]
    fn build_batch_expr_covers_all_kinds() {
        let cases = vec![
            ("eq".into(), Claim::Eq { left_expr: "1".into(), right_expr: "2".into() }),
            ("sub".into(), Claim::Subset { expr: "v".into(), expected_subset: json!({}) }),
            ("has".into(), Claim::HasAttrs { expr: "v".into(), attrs: vec!["a".into()] }),
            ("snap".into(), Claim::Snapshot { name: "g".into(), expr: "v".into() }),
        ];
        let (expr, slots) = build_batch_expr(&cases);
        assert!(expr.contains("subset"));
        assert!(expr.contains("hasAttrs"));
        assert!(expr.contains("attrNames"));
        assert_eq!(slots.len(), 4);
        assert!(nix_string_literal(r#"a"b\$"#).contains("\\"));
    }

    #[test]
    fn run_batch_mock_json_paths() {
        let cases = vec![
            ("eq_ok".into(), Claim::Eq { left_expr: "1".into(), right_expr: "1".into() }),
            ("eq_fail".into(), Claim::Eq { left_expr: "1".into(), right_expr: "2".into() }),
        ];
        let results = json!({
            BATCH_MARKER: true,
            "results": [
                {"kind": "eq", "left": {"ok": true, "value": 1}, "right": {"ok": true, "value": 1}},
                {"kind": "eq", "left": {"ok": true, "value": 1}, "right": {"ok": true, "value": 2}},
            ]
        });
        let eval = MockBatchJsonEval { inner: MockNixEval::default(), results };
        let store = SnapshotStore::new(PathBuf::from("/tmp/assay-batch-mock"));
        let outs = run_batch(&cases, &eval, &store).expect("batch");
        assert_eq!(outs.len(), 2);
        assert!(matches!(outs[0].1, Exit::Success(CaseVerdict::Pass)));
        assert!(matches!(outs[1].1, Exit::Success(CaseVerdict::AssertFail { .. })));
    }

    struct FailingBatchEval(MockNixEval);

    impl EvalBackend for FailingBatchEval {
        fn eval_json(&self, expr: &str) -> EvalResult {
            if expr.contains(BATCH_MARKER) {
                return EvalResult::Err(AssayOutcome::EvalError {
                    kind: "batch".into(),
                    message: "forced batch failure".into(),
                    span: None,
                });
            }
            self.0.eval_json(expr)
        }
    }

    #[test]
    fn run_batch_fallback_runs_isolated_interpreter() {
        let mock = MockNixEval::default();
        mock.set("a", EvalResult::Ok(json!(1)));
        let cases = vec![("eq".into(), Claim::Eq { left_expr: "a".into(), right_expr: "a".into() })];
        let store = SnapshotStore::new(PathBuf::from("/tmp/assay-batch-fallback"));
        let outs = run_batch(&cases, &FailingBatchEval(mock), &store).expect("fallback");
        assert!(matches!(outs[0].1, Exit::Success(CaseVerdict::Pass)));
    }

    #[test]
    fn is_batchable_covers_non_batchable_variants() {
        assert!(!is_batchable(&Claim::EqValues { left: json!(1), right: json!(1) }));
        assert!(!is_batchable(&Claim::Forces { expr: "x".into(), paths: vec![] }));
        assert!(!is_batchable(&Claim::Module { imports_expr: "[]".into(), args_expr: "{}".into(), expect: json!({}) }));
        assert!(!is_batchable(&Claim::Prop { name: "always_pass".into(), seed: 1, trials: None }));
    }

    #[test]
    #[ignore = "requires nix in PATH"]
    fn live_batch_eq_and_bare_throws() {
        let cases = vec![
            (
                "ok".into(),
                Claim::Eq {
                    left_expr: "1 + 1".into(),
                    right_expr: "2".into(),
                },
            ),
            (
                "multi".into(),
                Claim::Eq {
                    left_expr: "let\n  x = \"foo\" + \"bar\";\nin x".into(),
                    right_expr: "\"foobar\"".into(),
                },
            ),
            (
                "bad".into(),
                Claim::Eq {
                    left_expr: "1".into(),
                    right_expr: "2".into(),
                },
            ),
        ];
        let store = SnapshotStore::new(PathBuf::from("/tmp/assay-batch-test-goldens"));
        let outs = run_batch(&cases, &ProcessNixEval, &store).expect("batch");
        assert_eq!(outs.len(), 3);
        assert!(matches!(outs[0].1, Exit::Success(CaseVerdict::Pass)));
        assert!(matches!(outs[1].1, Exit::Success(CaseVerdict::Pass)));
        assert!(matches!(
            outs[2].1,
            Exit::Success(CaseVerdict::AssertFail { .. })
        ));
    }

    #[test]
    fn eval_batch_expr_force_json_missing_results() {
        FORCE_BATCH_JSON_EVAL.with(|f| {
            f.set(true);
            let eval = MockBatchJsonEval {
                inner: MockNixEval::default(),
                results: json!({ BATCH_MARKER: true }),
            };
            let cases = vec![(
                "eq".into(),
                Claim::Eq {
                    left_expr: "1".into(),
                    right_expr: "1".into(),
                },
            )];
            let store = SnapshotStore::new(PathBuf::from("/tmp/assay-batch-missing-results"));
            let err = run_batch(&cases, &eval, &store).unwrap_err();
            assert!(matches!(err, InfraError::Worker(_)));
            f.set(false);
        });
    }

    #[test]
    fn eval_batch_expr_force_json_count_mismatch() {
        FORCE_BATCH_JSON_EVAL.with(|f| {
            f.set(true);
            let results = json!({
                BATCH_MARKER: true,
                "results": [{"kind": "eq", "left": {"ok": true, "value": 1}, "right": {"ok": true, "value": 1}}]
            });
            let eval = MockBatchJsonEval {
                inner: MockNixEval::default(),
                results,
            };
            let cases = vec![
                ("a".into(), Claim::Eq { left_expr: "1".into(), right_expr: "1".into() }),
                ("b".into(), Claim::Eq { left_expr: "2".into(), right_expr: "2".into() }),
            ];
            let store = SnapshotStore::new(PathBuf::from("/tmp/assay-batch-count"));
            let err = run_batch(&cases, &eval, &store).unwrap_err();
            assert!(matches!(err, InfraError::Worker(_)));
            f.set(false);
        });
    }

    #[test]
    fn eval_batch_expr_force_json_eval_error() {
        FORCE_BATCH_JSON_EVAL.with(|f| {
            f.set(true);
            struct ErrEval;
            impl EvalBackend for ErrEval {
                fn eval_json(&self, _expr: &str) -> EvalResult {
                    EvalResult::Err(AssayOutcome::EvalError {
                        kind: "batch".into(),
                        message: "boom".into(),
                        span: None,
                    })
                }
            }
            let cases = vec![(
                "eq".into(),
                Claim::Eq {
                    left_expr: "1".into(),
                    right_expr: "1".into(),
                },
            )];
            let store = SnapshotStore::new(PathBuf::from("/tmp/assay-batch-err"));
            let outs = run_batch(&cases, &ErrEval, &store).expect("fallback");
            assert_eq!(outs.len(), 1);
            f.set(false);
        });
    }

    #[test]
    fn eval_batch_expr_force_json_non_eval_error() {
        FORCE_BATCH_JSON_EVAL.with(|f| {
            f.set(true);
            struct RecEval;
            impl EvalBackend for RecEval {
                fn eval_json(&self, _expr: &str) -> EvalResult {
                    EvalResult::Err(AssayOutcome::Recursion)
                }
            }
            let cases = vec![(
                "eq".into(),
                Claim::Eq {
                    left_expr: "1".into(),
                    right_expr: "1".into(),
                },
            )];
            let store = SnapshotStore::new(PathBuf::from("/tmp/assay-batch-rec"));
            let outs = run_batch(&cases, &RecEval, &store).expect("fallback");
            assert_eq!(outs.len(), 1);
            f.set(false);
        });
    }

    #[test]
    fn slot_outcome_eq_right_throw_and_subset_decode_err() {
        let store = SnapshotStore::new(PathBuf::from("/tmp/assay-slot-extra"));
        let eq = sample_slot("eq", BatchKind::Eq);
        let right_throw = json!({
            "kind": "eq",
            "left": {"ok": true, "value": 1},
            "right": {"ok": false}
        });
        assert!(matches!(slot_outcome(&eq, &right_throw, &store), AssayOutcome::EvalError { .. }));

        let subset = sample_slot("s", BatchKind::Subset { expected: json!({"a": 1}) });
        let bad_decode = json!({"kind": "subset", "primary": "nope"});
        assert!(matches!(slot_outcome(&subset, &bad_decode, &store), AssayOutcome::EvalError { .. }));

        let subset_throw = json!({"kind": "subset", "primary": {"ok": false}});
        assert!(matches!(slot_outcome(&subset, &subset_throw, &store), AssayOutcome::EvalError { .. }));

        let has = sample_slot("h", BatchKind::HasAttrs { attrs: vec!["a".into()] });
        let has_false = json!({"kind": "hasAttrs", "primary": {"ok": false}});
        assert!(matches!(slot_outcome(&has, &has_false, &store), AssayOutcome::EvalError { .. }));
        let has_none = json!({"kind": "hasAttrs", "primary": {"oops": true}});
        assert!(matches!(slot_outcome(&has, &has_none, &store), AssayOutcome::EvalError { .. }));

        let snap = sample_slot("snap", BatchKind::Snapshot { snap_name: "g".into() });
        let snap_throw = json!({"kind": "snapshot", "primary": {"ok": false}});
        assert!(matches!(slot_outcome(&snap, &snap_throw, &store), AssayOutcome::EvalError { .. }));
    }

    #[test]
    fn run_batch_trace_env_does_not_panic() {
        unsafe {
            std::env::set_var("ASSAY_TRACE", "1");
        }
        let cases = vec![(
            "eq".into(),
            Claim::Eq {
                left_expr: "1".into(),
                right_expr: "1".into(),
            },
        )];
        let results = json!({
            BATCH_MARKER: true,
            "results": [{"kind": "eq", "left": {"ok": true, "value": 1}, "right": {"ok": true, "value": 1}}]
        });
        let eval = MockBatchJsonEval {
            inner: MockNixEval::default(),
            results,
        };
        let store = SnapshotStore::new(PathBuf::from("/tmp/assay-batch-trace"));
        FORCE_BATCH_JSON_EVAL.with(|f| {
            f.set(true);
            let _ = run_batch(&cases, &eval, &store);
            f.set(false);
        });
        unsafe {
            std::env::remove_var("ASSAY_TRACE");
        }
    }

    #[test]
    fn nix_file_eval_fallback_to_json_ok() {
        BATCH_NIX_FILE_EVAL.with(|c| {
            c.set(Some(AssayOutcome::EvalError {
                kind: "throw".into(),
                message: "file fail".into(),
                span: None,
            }));
        });
        let cases = vec![(
            "eq".into(),
            Claim::Eq {
                left_expr: "1".into(),
                right_expr: "1".into(),
            },
        )];
        let results = json!({
            BATCH_MARKER: true,
            "results": [{"kind": "eq", "left": {"ok": true, "value": 1}, "right": {"ok": true, "value": 1}}]
        });
        let eval = MockBatchJsonEval {
            inner: MockNixEval::default(),
            results,
        };
        let store = SnapshotStore::new(PathBuf::from("/tmp/assay-file-fallback-ok"));
        let outs = run_batch(&cases, &eval, &store).expect("batch");
        assert_eq!(outs.len(), 1);
        assert!(matches!(outs[0].1, Exit::Success(CaseVerdict::Pass)));
    }

    #[test]
    fn nix_file_eval_dual_eval_error_triggers_fallback() {
        BATCH_NIX_FILE_EVAL.with(|c| {
            c.set(Some(AssayOutcome::EvalError {
                kind: "throw".into(),
                message: "file fail".into(),
                span: None,
            }));
        });
        struct DualFail;
        impl EvalBackend for DualFail {
            fn eval_json(&self, expr: &str) -> EvalResult {
                if expr.contains(BATCH_MARKER) {
                    EvalResult::Err(AssayOutcome::EvalError {
                        kind: "throw".into(),
                        message: "batch fail".into(),
                        span: None,
                    })
                } else {
                    EvalResult::Ok(json!(1))
                }
            }
        }
        let cases = vec![(
            "eq".into(),
            Claim::Eq {
                left_expr: "1".into(),
                right_expr: "1".into(),
            },
        )];
        let store = SnapshotStore::new(PathBuf::from("/tmp/assay-dual-fail"));
        let outs = run_batch(&cases, &DualFail, &store).expect("fallback");
        assert_eq!(outs.len(), 1);
    }

    #[test]
    fn nix_file_eval_recursion_fallback_ok() {
        BATCH_NIX_FILE_EVAL.with(|c| c.set(Some(AssayOutcome::Recursion)));
        let cases = vec![(
            "eq".into(),
            Claim::Eq {
                left_expr: "1".into(),
                right_expr: "1".into(),
            },
        )];
        let results = json!({
            BATCH_MARKER: true,
            "results": [{"kind": "eq", "left": {"ok": true, "value": 1}, "right": {"ok": true, "value": 1}}]
        });
        let eval = MockBatchJsonEval {
            inner: MockNixEval::default(),
            results,
        };
        let store = SnapshotStore::new(PathBuf::from("/tmp/assay-rec-fallback"));
        let outs = run_batch(&cases, &eval, &store).expect("batch");
        assert_eq!(outs.len(), 1);
    }

    #[test]
    fn batch_trace_on_file_eval_failure() {
        unsafe {
            std::env::set_var("ASSAY_TRACE", "1");
        }
        BATCH_NIX_FILE_EVAL.with(|c| {
            c.set(Some(AssayOutcome::EvalError {
                kind: "throw".into(),
                message: "file fail".into(),
                span: None,
            }));
        });
        struct BatchFail;
        impl EvalBackend for BatchFail {
            fn eval_json(&self, expr: &str) -> EvalResult {
                if expr.contains(BATCH_MARKER) {
                    EvalResult::Err(AssayOutcome::EvalError {
                        kind: "throw".into(),
                        message: "batch".into(),
                        span: None,
                    })
                } else {
                    EvalResult::Ok(json!(1))
                }
            }
        }
        let cases = vec![(
            "eq".into(),
            Claim::Eq {
                left_expr: "1".into(),
                right_expr: "1".into(),
            },
        )];
        let store = SnapshotStore::new(PathBuf::from("/tmp/assay-trace-fail"));
        let _ = run_batch(&cases, &BatchFail, &store);
        unsafe {
            std::env::remove_var("ASSAY_TRACE");
        }
    }

    #[test]
    fn mock_batch_json_eval_delegates_to_inner() {
        let inner = MockNixEval::default();
        inner.set("plain", EvalResult::Ok(json!(42)));
        let eval = MockBatchJsonEval {
            inner,
            results: json!({}),
        };
        assert_eq!(eval.eval_json("plain"), EvalResult::Ok(json!(42)));
    }

    #[test]
    fn run_batch_fallback_maps_interpret_infra_error() {
        BATCH_NIX_FILE_EVAL.with(|c| {
            c.set(Some(AssayOutcome::EvalError {
                kind: "throw".into(),
                message: "file".into(),
                span: None,
            }));
        });
        struct IoOnIsolate;
        impl EvalBackend for IoOnIsolate {
            fn eval_json(&self, expr: &str) -> EvalResult {
                if expr.contains(BATCH_MARKER) {
                    EvalResult::Err(AssayOutcome::EvalError {
                        kind: "throw".into(),
                        message: "batch".into(),
                        span: None,
                    })
                } else {
                    EvalResult::Err(AssayOutcome::EvalError {
                        kind: "io".into(),
                        message: "disk".into(),
                        span: None,
                    })
                }
            }
        }
        let cases = vec![(
            "eq".into(),
            Claim::Eq {
                left_expr: "1".into(),
                right_expr: "1".into(),
            },
        )];
        let store = SnapshotStore::new(PathBuf::from("/tmp/assay-fallback-infra"));
        let outs = run_batch(&cases, &IoOnIsolate, &store).expect("fallback");
        assert!(matches!(outs[0].1, Exit::Failure(_)));
    }
}
