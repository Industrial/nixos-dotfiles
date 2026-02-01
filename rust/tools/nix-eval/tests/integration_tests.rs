//! Integration tests for nix-eval
//!
//! These tests verify the end-to-end behavior of the evaluator,
//! testing complete evaluation workflows rather than individual functions.

use nix_eval::{Evaluator, NixValue};
use std::collections::HashMap;

#[test]
fn test_evaluate_simple_integer() {
    let evaluator = Evaluator::new();
    let result = evaluator.evaluate("42").unwrap();
    assert_eq!(result, NixValue::Integer(42));
}

#[test]
fn test_evaluate_simple_string() {
    let evaluator = Evaluator::new();
    let result = evaluator.evaluate(r#""hello world""#).unwrap();
    assert_eq!(result, NixValue::String("hello world".to_string()));
}

#[test]
fn test_evaluate_string_with_escapes() {
    let evaluator = Evaluator::new();
    let result = evaluator.evaluate(r#""hello\nworld""#).unwrap();
    assert_eq!(result, NixValue::String("hello\nworld".to_string()));
}

#[test]
fn test_evaluate_boolean_values() {
    let evaluator = Evaluator::new();
    assert_eq!(evaluator.evaluate("true").unwrap(), NixValue::Boolean(true));
    assert_eq!(
        evaluator.evaluate("false").unwrap(),
        NixValue::Boolean(false)
    );
}

#[test]
fn test_evaluate_null() {
    let evaluator = Evaluator::new();
    assert_eq!(evaluator.evaluate("null").unwrap(), NixValue::Null);
}

#[test]
fn test_evaluate_float() {
    let evaluator = Evaluator::new();
    let result = evaluator.evaluate("3.14").unwrap();
    match result {
        NixValue::Float(f) => assert!((f - 3.14).abs() < 0.001),
        _ => panic!("Expected Float"),
    }
}

#[test]
fn test_evaluate_simple_list() {
    let evaluator = Evaluator::new();
    let result = evaluator.evaluate("[1 2 3]").unwrap();
    match result {
        NixValue::List(items) => {
            assert_eq!(items.len(), 3);
            assert_eq!(items[0], NixValue::Integer(1));
            assert_eq!(items[1], NixValue::Integer(2));
            assert_eq!(items[2], NixValue::Integer(3));
        }
        _ => panic!("Expected List"),
    }
}

#[test]
fn test_evaluate_mixed_list() {
    let evaluator = Evaluator::new();
    let result = evaluator.evaluate(r#"["hello" 42 true null]"#).unwrap();
    match result {
        NixValue::List(items) => {
            assert_eq!(items.len(), 4);
            assert_eq!(items[0], NixValue::String("hello".to_string()));
            assert_eq!(items[1], NixValue::Integer(42));
            assert_eq!(items[2], NixValue::Boolean(true));
            assert_eq!(items[3], NixValue::Null);
        }
        _ => panic!("Expected List"),
    }
}

#[test]
fn test_evaluate_nested_list() {
    let evaluator = Evaluator::new();
    let result = evaluator.evaluate("[[1 2] [3 4]]").unwrap();
    match result {
        NixValue::List(outer) => {
            assert_eq!(outer.len(), 2);
            match &outer[0] {
                NixValue::List(inner) => {
                    assert_eq!(inner.len(), 2);
                    assert_eq!(inner[0], NixValue::Integer(1));
                    assert_eq!(inner[1], NixValue::Integer(2));
                }
                _ => panic!("Expected nested List"),
            }
        }
        _ => panic!("Expected List"),
    }
}

#[test]
fn test_evaluate_simple_attribute_set() {
    let evaluator = Evaluator::new();
    let result = evaluator.evaluate("{ foo = 1; bar = 2; }").unwrap();
    match result {
        NixValue::AttributeSet(attrs) => {
            assert_eq!(attrs.len(), 2);
            assert_eq!(attrs.get("foo"), Some(&NixValue::Integer(1)));
            assert_eq!(attrs.get("bar"), Some(&NixValue::Integer(2)));
        }
        _ => panic!("Expected AttributeSet"),
    }
}

#[test]
fn test_evaluate_attribute_set_with_mixed_values() {
    let evaluator = Evaluator::new();
    let result = evaluator
        .evaluate(r#"{ name = "test"; value = 42; enabled = true; }"#)
        .unwrap();
    match result {
        NixValue::AttributeSet(attrs) => {
            assert_eq!(attrs.len(), 3);
            assert_eq!(
                attrs.get("name"),
                Some(&NixValue::String("test".to_string()))
            );
            assert_eq!(attrs.get("value"), Some(&NixValue::Integer(42)));
            assert_eq!(attrs.get("enabled"), Some(&NixValue::Boolean(true)));
        }
        _ => panic!("Expected AttributeSet"),
    }
}

#[test]
fn test_evaluate_nested_attribute_set() {
    let evaluator = Evaluator::new();
    let result = evaluator.evaluate("{ outer = { inner = 42; }; }").unwrap();
    match result {
        NixValue::AttributeSet(outer) => {
            assert_eq!(outer.len(), 1);
            match outer.get("outer") {
                Some(NixValue::AttributeSet(inner)) => {
                    assert_eq!(inner.get("inner"), Some(&NixValue::Integer(42)));
                }
                _ => panic!("Expected nested AttributeSet"),
            }
        }
        _ => panic!("Expected AttributeSet"),
    }
}

#[test]
fn test_evaluate_attribute_set_with_list() {
    let evaluator = Evaluator::new();
    let result = evaluator.evaluate("{ items = [1 2 3]; }").unwrap();
    match result {
        NixValue::AttributeSet(attrs) => match attrs.get("items") {
            Some(NixValue::List(items)) => {
                assert_eq!(items.len(), 3);
            }
            _ => panic!("Expected List in AttributeSet"),
        },
        _ => panic!("Expected AttributeSet"),
    }
}

#[test]
fn test_evaluate_empty_list() {
    let evaluator = Evaluator::new();
    let result = evaluator.evaluate("[]").unwrap();
    match result {
        NixValue::List(items) => assert_eq!(items.len(), 0),
        _ => panic!("Expected empty List"),
    }
}

#[test]
fn test_evaluate_empty_attribute_set() {
    let evaluator = Evaluator::new();
    let result = evaluator.evaluate("{}").unwrap();
    match result {
        NixValue::AttributeSet(attrs) => assert_eq!(attrs.len(), 0),
        _ => panic!("Expected empty AttributeSet"),
    }
}

#[test]
fn test_parse_error_invalid_syntax() {
    let evaluator = Evaluator::new();
    let result = evaluator.evaluate("invalid syntax {");
    assert!(result.is_err());
    match result.unwrap_err() {
        nix_eval::Error::ParseError { .. } => {}
        _ => panic!("Expected ParseError"),
    }
}

#[test]
fn test_parse_error_unclosed_string() {
    let evaluator = Evaluator::new();
    let result = evaluator.evaluate(r#""unclosed string"#);
    assert!(result.is_err());
}

#[test]
fn test_display_formatting() {
    let evaluator = Evaluator::new();

    // Test that Display trait works correctly
    let value = evaluator.evaluate("42").unwrap();
    assert_eq!(format!("{}", value), "42");

    let value = evaluator.evaluate(r#""hello""#).unwrap();
    assert_eq!(format!("{}", value), r#""hello""#);

    let value = evaluator.evaluate("true").unwrap();
    assert_eq!(format!("{}", value), "true");

    let value = evaluator.evaluate("[1 2 3]").unwrap();
    let formatted = format!("{}", value);
    assert!(formatted.contains("1"));
    assert!(formatted.contains("2"));
    assert!(formatted.contains("3"));
}

#[test]
fn test_json_serialization() {
    let evaluator = Evaluator::new();

    // Test that values can be serialized to JSON
    let value = evaluator.evaluate("42").unwrap();
    let json = serde_json::to_string(&value).unwrap();
    assert!(json.contains("integer"));
    assert!(json.contains("42"));

    let value = evaluator.evaluate(r#""hello""#).unwrap();
    let json = serde_json::to_string(&value).unwrap();
    assert!(json.contains("string"));
    assert!(json.contains("hello"));

    let value = evaluator.evaluate("[1 2 3]").unwrap();
    let json = serde_json::to_string(&value).unwrap();
    assert!(json.contains("list"));
}

#[test]
fn test_variable_scope_resolution() {
    let mut evaluator = Evaluator::new();
    let mut scope = HashMap::new();
    scope.insert("x".to_string(), NixValue::Integer(42));
    scope.insert("y".to_string(), NixValue::String("hello".to_string()));
    evaluator.set_scope(scope);

    // Test that variables in scope can be resolved
    let result = evaluator.evaluate("x").unwrap();
    assert_eq!(result, NixValue::Integer(42));

    let result = evaluator.evaluate("y").unwrap();
    assert_eq!(result, NixValue::String("hello".to_string()));
}

#[test]
fn test_unknown_variable_error() {
    let evaluator = Evaluator::new();
    let result = evaluator.evaluate("unknownVar");
    assert!(result.is_err());
    match result.unwrap_err() {
        nix_eval::Error::UnsupportedExpression { reason } => {
            assert!(reason.contains("unknown identifier"));
        }
        _ => panic!("Expected UnsupportedExpression for unknown variable"),
    }
}
