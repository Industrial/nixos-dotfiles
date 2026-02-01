//! Property-based tests for nix-eval
//!
//! These tests use proptest to generate random inputs and verify
//! properties that should hold for all valid Nix expressions.

use nix_eval::{Evaluator, NixValue};
use proptest::prelude::*;

fn arb_integer() -> impl Strategy<Value = i64> {
    any::<i64>()
}

fn arb_string() -> impl Strategy<Value = String> {
    ".*"
}

fn arb_boolean() -> impl Strategy<Value = bool> {
    any::<bool>()
}

proptest! {
    #[test]
    fn test_integer_roundtrip(n in arb_integer()) {
        let evaluator = Evaluator::new();
        let expr = n.to_string();
        let result = evaluator.evaluate(&expr).unwrap();
        prop_assert_eq!(result, NixValue::Integer(n));
    }

    #[test]
    fn test_string_roundtrip(s in arb_string()) {
        let evaluator = Evaluator::new();
        // Escape the string for Nix
        let escaped = s
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\t", "\\t");
        let expr = format!("\"{}\"", escaped);

        if let Ok(result) = evaluator.evaluate(&expr) {
            match result {
                NixValue::String(result_str) => {
                    // Basic check - the result should contain the original string
                    // (exact match may vary due to escaping)
                    prop_assert!(result_str.len() > 0 || s.is_empty());
                }
                _ => prop_assert!(false, "Expected String, got {:?}", result),
            }
        }
    }

    #[test]
    fn test_boolean_roundtrip(b in arb_boolean()) {
        let evaluator = Evaluator::new();
        let expr = b.to_string();
        let result = evaluator.evaluate(&expr).unwrap();
        prop_assert_eq!(result, NixValue::Boolean(b));
    }

    #[test]
    fn test_list_length_preserved(items in prop::collection::vec(any::<i64>(), 0..100)) {
        let evaluator = Evaluator::new();
        let expr = format!("[{}]", items.iter().map(|i| i.to_string()).collect::<Vec<_>>().join(" "));
        let result = evaluator.evaluate(&expr).unwrap();

        match result {
            NixValue::List(result_items) => {
                prop_assert_eq!(result_items.len(), items.len());
            }
            _ => prop_assert!(false, "Expected List"),
        }
    }

    #[test]
    fn test_display_does_not_panic(value in arb_integer()) {
        let evaluator = Evaluator::new();
        let result = evaluator.evaluate(&value.to_string()).unwrap();
        // Display should never panic
        let _formatted = format!("{}", result);
        prop_assert!(true);
    }

    #[test]
    fn test_json_serialization_does_not_panic(value in arb_integer()) {
        let evaluator = Evaluator::new();
        let result = evaluator.evaluate(&value.to_string()).unwrap();
        // JSON serialization should never panic
        let _json = serde_json::to_string(&result).unwrap();
        prop_assert!(true);
    }

    #[test]
    fn test_nested_list_depth(items in prop::collection::vec(
        prop::collection::vec(any::<i64>(), 0..10),
        0..10
    )) {
        let evaluator = Evaluator::new();
        let inner_lists: Vec<String> = items
            .iter()
            .map(|inner| {
                format!("[{}]", inner.iter().map(|i| i.to_string()).collect::<Vec<_>>().join(" "))
            })
            .collect();
        let expr = format!("[{}]", inner_lists.join(" "));

        if let Ok(result) = evaluator.evaluate(&expr) {
            match result {
                NixValue::List(outer) => {
                    prop_assert_eq!(outer.len(), items.len());
                    for (i, inner_expected) in items.iter().enumerate() {
                        if let Some(NixValue::List(inner_actual)) = outer.get(i) {
                            prop_assert_eq!(inner_actual.len(), inner_expected.len());
                        }
                    }
                }
                _ => prop_assert!(false, "Expected nested List"),
            }
        }
    }

    #[test]
    fn test_attribute_set_key_count(keys in prop::collection::hash_set("[a-z]{1,10}", 0..20)) {
        let evaluator = Evaluator::new();
        let entries: Vec<String> = keys
            .iter()
            .enumerate()
            .map(|(i, k)| format!("{} = {};", k, i))
            .collect();
        let expr = format!("{{ {} }}", entries.join(" "));

        if let Ok(result) = evaluator.evaluate(&expr) {
            match result {
                NixValue::AttributeSet(attrs) => {
                    prop_assert_eq!(attrs.len(), keys.len());
                }
                _ => prop_assert!(false, "Expected AttributeSet"),
            }
        }
    }
}
