//! Deterministic property generators and trial runner.

use serde_json::{Map, Value};

use crate::outcome::AssayOutcome;

const MAX_STRING_LEN: usize = 16;
const MAX_COLLECTION_LEN: usize = 4;

/// Built-in property names for suite `prop` claims.
pub const BUILTIN_PROP_NAMES: &[&str] = &["always_pass", "merge_idempotent"];

/// Run a built-in property by name.
pub fn run_prop_by_name(name: &str, seed: u64, trials: u32) -> AssayOutcome {
    match name {
        "always_pass" => prop_assert(seed, trials, |_| Ok(())),
        "merge_idempotent" => crate::laws::law_merge_idempotent(seed),
        other => AssayOutcome::EvalError {
            kind: "prop".into(),
            message: format!("unknown property: {other}"),
            span: None,
        },
    }
}


/// Seeded pseudo-random generator with a stable value sequence per seed.
#[derive(Debug, Clone)]
pub struct Gen {
    state: u64,
}

impl Gen {
    pub fn new(seed: u64) -> Self {
        Self {
            state: seed.max(1),
        }
    }

    pub fn gen_bool(&mut self) -> bool {
        self.next_u64() & 1 == 0
    }

    pub fn gen_u32(&mut self, max_exclusive: u32) -> u32 {
        if max_exclusive <= 1 {
            return 0;
        }
        (self.next_u64() % u64::from(max_exclusive)) as u32
    }

    pub fn gen_string(&mut self, max_len: usize) -> String {
        let len = if max_len == 0 {
            0
        } else {
            self.gen_u32(max_len as u32 + 1) as usize
        };
        (0..len)
            .map(|_| {
                let code = 32 + (self.next_u64() % 95) as u8;
                char::from(code)
            })
            .collect()
    }

    pub fn gen_json(&mut self, depth: u32) -> Value {
        if depth == 0 {
            return self.gen_leaf();
        }

        match self.gen_u32(6) {
            0 => Value::Null,
            1 => Value::Bool(self.gen_bool()),
            2 => Value::Number(self.gen_u32(256).into()),
            3 => Value::String(self.gen_string(MAX_STRING_LEN)),
            4 => self.gen_array(depth),
            _ => self.gen_object(depth),
        }
    }

    fn gen_leaf(&mut self) -> Value {
        match self.gen_u32(4) {
            0 => Value::Null,
            1 => Value::Bool(self.gen_bool()),
            2 => Value::Number(self.gen_u32(256).into()),
            _ => Value::String(self.gen_string(MAX_STRING_LEN)),
        }
    }

    fn gen_array(&mut self, depth: u32) -> Value {
        let len = self.gen_u32(MAX_COLLECTION_LEN as u32 + 1) as usize;
        Value::Array(
            (0..len)
                .map(|_| self.gen_json(depth - 1))
                .collect(),
        )
    }

    fn gen_object(&mut self, depth: u32) -> Value {
        let len = self.gen_u32(MAX_COLLECTION_LEN as u32 + 1) as usize;
        let mut map = Map::new();
        for _ in 0..len {
            let key = format!("k{}", self.gen_u32(256));
            map.insert(key, self.gen_json(depth - 1));
        }
        Value::Object(map)
    }

    fn next_u64(&mut self) -> u64 {
        let mut x = self.state;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.state = x;
        x
    }
}

/// Run `trials` property checks; failures return a seeded counterexample.
pub fn prop_assert(
    seed: u64,
    trials: u32,
    mut property: impl FnMut(&mut Gen) -> Result<(), Value>,
) -> AssayOutcome {
    let mut rng = Gen::new(seed);
    for _ in 0..trials {
        if let Err(counterexample) = property(&mut rng) {
            return AssayOutcome::Counterexample {
                seed,
                shrunk: shrink_value(&counterexample),
            };
        }
    }
    AssayOutcome::Pass
}

fn shrink_value(value: &Value) -> Value {
    let mut current = value.clone();
    loop {
        let next = shrink_once(&current);
        if next == current {
            return current;
        }
        current = next;
    }
}

fn shrink_once(value: &Value) -> Value {
    match value {
        Value::Array(items) if items.len() > 1 => Value::Array(items[..items.len() - 1].to_vec()),
        Value::Array(items) if !items.is_empty() => items[0].clone(),
        Value::Object(map) if map.len() > 1 => {
            let key = map.keys().next().expect("non-empty map").clone();
            let mut shrunk = Map::new();
            shrunk.insert(key.clone(), map[&key].clone());
            Value::Object(shrunk)
        }
        Value::String(text) if !text.is_empty() => Value::String(text[..text.len() / 2].into()),
        Value::Number(number) => {
            let n = number.as_u64().unwrap_or(0);
            Value::Number((n / 2).into())
        }
        _ => value.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Value;

    #[test]
    fn same_seed_produces_same_sequence() {
        let mut left = Gen::new(42);
        let mut right = Gen::new(42);
        for _ in 0..64 {
            assert_eq!(left.gen_bool(), right.gen_bool());
            assert_eq!(left.gen_u32(17), right.gen_u32(17));
            assert_eq!(left.gen_string(8), right.gen_string(8));
            assert_eq!(left.gen_json(2), right.gen_json(2));
        }
    }

    #[test]
    fn prop_assert_passes_when_property_holds() {
        let outcome = prop_assert(7, 50, |_| Ok(()));
        assert_eq!(outcome, AssayOutcome::Pass);
    }

    #[test]
    fn prop_assert_returns_counterexample_on_failure() {
        let outcome = prop_assert(99, 10, |_| Err(Value::String("boom".into())));
        assert!(matches!(
            outcome,
            AssayOutcome::Counterexample { seed: 99, .. }
        ));
    }

    #[test]
    fn run_prop_by_name_unknown_returns_eval_error() {
        let outcome = run_prop_by_name("__no_such_prop__", 1, 1);
        assert!(matches!(outcome, AssayOutcome::EvalError { .. }));
    }

    #[test]
    fn run_prop_by_name_always_pass() {
        assert_eq!(run_prop_by_name("always_pass", 1, 10), AssayOutcome::Pass);
    }

    #[test]
    fn counterexample_is_shrunk() {
        let failing = Value::Array(vec![
            Value::Number(10.into()),
            Value::Number(20.into()),
        ]);
        let outcome = prop_assert(1, 1, |_| Err(failing.clone()));
        match outcome {
            AssayOutcome::Counterexample { shrunk, .. } => {
                assert_ne!(shrunk, failing);
            }
            other => panic!("expected counterexample, got {other:?}"),
        }
    }

    #[test]
    fn shrink_once_covers_object_number_string() {
        let obj = Value::Object(serde_json::Map::from_iter([
            ("a".into(), Value::Number(1.into())),
            ("b".into(), Value::Number(2.into())),
        ]));
        let shrunk = shrink_once(&obj);
        assert!(matches!(shrunk, Value::Object(_)));
        let num = Value::Number(10.into());
        assert!(matches!(shrink_once(&num), Value::Number(_)));
        let s = Value::String("hello".into());
        assert!(matches!(shrink_once(&s), Value::String(_)));
    }

    #[test]
    fn shrink_once_single_element_array_and_fallback() {
        let one = Value::Array(vec![Value::Number(9.into())]);
        assert_eq!(shrink_once(&one), Value::Number(9.into()));
        let empty = Value::Array(vec![]);
        assert_eq!(shrink_once(&empty), empty);
        assert_eq!(shrink_once(&Value::Bool(true)), Value::Bool(true));
        assert_eq!(shrink_once(&Value::Null), Value::Null);
    }

    #[test]
    fn shrink_once_integer_number() {
        let shrunk = shrink_once(&Value::Number(10.into()));
        assert_eq!(shrunk, Value::Number(5.into()));
    }

    #[test]
    fn gen_u32_and_string_zero_max() {
        let mut g = Gen::new(1);
        assert_eq!(g.gen_u32(1), 0);
        assert_eq!(g.gen_string(0), "");
    }

    #[test]
    fn gen_seed_zero_matches_seed_one() {
        let mut z = Gen::new(0);
        let mut o = Gen::new(1);
        assert_eq!(z.gen_bool(), o.gen_bool());
    }

    #[test]
    fn gen_json_depth_zero_uses_leaf() {
        let mut g = Gen::new(99);
        for _ in 0..8 {
            match g.gen_json(0) {
                Value::Array(_) | Value::Object(_) => panic!("depth 0 must be leaf"),
                _ => {}
            }
        }
    }
}
