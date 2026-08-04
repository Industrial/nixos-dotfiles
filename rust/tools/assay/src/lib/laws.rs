//! Algebraic laws for JSON object merge (`//`-style, last-wins).

use serde_json::{Map, Value};

use crate::outcome::AssayOutcome;
use crate::prop::{Gen, prop_assert};

const LAW_TRIALS: u32 = 128;

/// Built-in law names exposed to suite `law` claims and the CLI.
pub const BUILTIN_LAW_NAMES: &[&str] = &[
    "merge_identity",
    "merge_associativity",
    "merge_idempotent",
];

/// Run a single built-in law by name.
pub fn run_law_by_name(name: &str, seed: u64) -> AssayOutcome {
    match name {
        "merge_identity" => law_merge_identity(seed),
        "merge_associativity" => law_merge_associativity(seed),
        "merge_idempotent" => law_merge_idempotent(seed),
        other => AssayOutcome::EvalError {
            kind: "law".into(),
            message: format!("unknown law: {other}"),
            span: None,
        },
    }
}


/// `a ∪ {} == a` and `{} ∪ a == a` for object maps.
pub fn law_merge_identity(seed: u64) -> AssayOutcome {
    prop_assert(seed, LAW_TRIALS, |rng| {
        let left = rng_object(rng);
        let empty = empty_object();
        let right_id = merge_maps(&left, &empty);
        let left_id = merge_maps(&empty, &left);
        match (right_id == left, left_id == left) {
            (true, true) => Ok(()),
            _ => Err(Value::Object(left)),
        }
    })
}

/// `(a ∪ b) ∪ c == a ∪ (b ∪ c)` for object maps.
pub fn law_merge_associativity(seed: u64) -> AssayOutcome {
    prop_assert(seed, LAW_TRIALS, |rng| {
        let a = rng_object(rng);
        let b = rng_object(rng);
        let c = rng_object(rng);
        let left = merge_maps(&merge_maps(&a, &b), &c);
        let right = merge_maps(&a, &merge_maps(&b, &c));
        if left == right {
            Ok(())
        } else {
            let mut counter = Map::new();
            counter.insert("a".into(), Value::Object(a));
            counter.insert("b".into(), Value::Object(b));
            counter.insert("c".into(), Value::Object(c));
            Err(Value::Object(counter))
        }
    })
}

/// `a ∪ a == a` for object maps.
pub fn law_merge_idempotent(seed: u64) -> AssayOutcome {
    prop_assert(seed, LAW_TRIALS, |rng| {
        let map = rng_object(rng);
        let merged = merge_maps(&map, &map);
        if merged == map {
            Ok(())
        } else {
            Err(Value::Object(map))
        }
    })
}

/// Run built-in algebraic law checks.
pub fn run_builtin_laws(seed: u64) -> Vec<(&'static str, AssayOutcome)> {
    vec![
        ("merge_identity", law_merge_identity(seed)),
        ("merge_associativity", law_merge_associativity(seed)),
        ("merge_idempotent", law_merge_idempotent(seed)),
    ]
}

fn rng_object(rng: &mut Gen) -> Map<String, Value> {
    match rng.gen_json(2) {
        Value::Object(map) => map,
        other => {
            let mut map = Map::new();
            map.insert("value".into(), other);
            map
        }
    }
}

fn empty_object() -> Map<String, Value> {
    Map::new()
}

#[cfg(test)]
thread_local! {
    static FORCE_BAD_MERGE: std::cell::Cell<bool> = const { std::cell::Cell::new(false) };
}

fn merge_maps(
    left: &Map<String, Value>,
    right: &Map<String, Value>,
) -> Map<String, Value> {
    #[cfg(test)]
    if FORCE_BAD_MERGE.with(|flag| flag.get()) {
        if left == right {
            return Map::new();
        }
        return right.clone();
    }
    let mut merged = left.clone();
    for (key, value) in right {
        merged.insert(key.clone(), value.clone());
    }
    merged
}

#[cfg(test)]
struct BadMergeGuard;

#[cfg(test)]
impl BadMergeGuard {
    fn new() -> Self {
        FORCE_BAD_MERGE.with(|flag| flag.set(true));
        Self
    }
}

#[cfg(test)]
impl Drop for BadMergeGuard {
    fn drop(&mut self) {
        FORCE_BAD_MERGE.with(|flag| flag.set(false));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn merge_identity_holds_for_seed() {
        assert_eq!(law_merge_identity(1), AssayOutcome::Pass);
    }

    #[test]
    fn merge_associativity_holds_for_seed() {
        assert_eq!(law_merge_associativity(2), AssayOutcome::Pass);
    }

    #[test]
    fn merge_idempotent_holds_for_seed() {
        assert_eq!(law_merge_idempotent(3), AssayOutcome::Pass);
    }

    #[test]
    fn run_builtin_laws_returns_three_checks() {
        let laws = run_builtin_laws(11);
        assert_eq!(laws.len(), 3);
        assert!(laws.iter().all(|(_, outcome)| *outcome == AssayOutcome::Pass));
    }

    #[test]
    fn run_law_by_name_dispatches_merge_idempotent() {
        assert_eq!(run_law_by_name("merge_idempotent", 3), AssayOutcome::Pass);
    }

    #[test]
    fn run_law_by_name_dispatches_all_builtins() {
        assert_eq!(run_law_by_name("merge_identity", 1), AssayOutcome::Pass);
        assert_eq!(run_law_by_name("merge_associativity", 2), AssayOutcome::Pass);
    }

    #[test]
    fn bad_merge_hook_exercises_both_branches() {
        let _guard = BadMergeGuard::new();
        let mut a = Map::new();
        a.insert("x".into(), Value::Number(1.into()));
        let empty = Map::new();
        assert_eq!(merge_maps(&a, &empty), empty);
        assert_eq!(merge_maps(&a, &a), Map::new());
    }

    #[test]
    fn unknown_law_is_eval_error() {
        match run_law_by_name("no_such_law", 0) {
            AssayOutcome::EvalError { .. } => {}
            other => panic!("expected EvalError, got {other:?}"),
        }
    }

    #[test]
    fn merge_last_wins_on_key_collision() {
        let mut left = Map::new();
        left.insert("x".into(), Value::Number(1.into()));
        let mut right = Map::new();
        right.insert("x".into(), Value::Number(2.into()));
        let merged = merge_maps(&left, &right);
        assert_eq!(merged.get("x"), Some(&Value::Number(2.into())));
    }

    #[test]
    fn law_failure_branches_emit_counterexamples() {
        let _guard = BadMergeGuard::new();
        match law_merge_identity(1) {
            AssayOutcome::Counterexample { .. } => {}
            other => panic!("expected counterexample, got {other:?}"),
        }
        match law_merge_associativity(2) {
            AssayOutcome::Counterexample { .. } => {}
            other => panic!("expected counterexample, got {other:?}"),
        }
        match law_merge_idempotent(3) {
            AssayOutcome::Counterexample { .. } => {}
            other => panic!("expected counterexample, got {other:?}"),
        }
    }

    #[test]
    fn rng_object_wraps_non_object_json() {
        for seed in 0..512u64 {
            let mut rng = Gen::new(seed);
            let map = rng_object(&mut rng);
            if map.len() == 1 && map.contains_key("value") {
                return;
            }
        }
        panic!("expected rng_object wrap branch");
    }

    #[test]
    fn rng_object_can_return_single_non_value_key() {
        for seed in 0..4096u64 {
            let mut rng = Gen::new(seed);
            let map = rng_object(&mut rng);
            if map.len() == 1 && !map.contains_key("value") {
                return;
            }
        }
        panic!("expected single-key non-value object");
    }
}

#[cfg(feature = "proptest")]
mod proptest_laws {
    use super::*;
    use proptest::prelude::*;

    proptest! {
        #[test]
        fn merge_idempotent_holds_for_any_seed(seed in 0u64..512) {
            prop_assert_eq!(law_merge_idempotent(seed), AssayOutcome::Pass);
        }
    }
}

