//! JSON subset / attribute checks — Traversal-shaped folds over [`serde_json::Value`].

use serde_json::Value;

/// Fold over immediate object keys of `value` (no-op when not an object).
pub fn fold_object_keys(value: &Value, mut visit: impl FnMut(&str)) {
    if let Value::Object(map) = value {
        for key in map.keys() {
            visit(key);
        }
    }
}

/// Recursive structural subset: every key in `expected` exists in `actual` with matching values.
pub fn value_contains_subset(actual: &Value, expected: &Value) -> bool {
    match (actual, expected) {
        (Value::Object(a), Value::Object(e)) => e.iter().all(|(k, v)| {
            a.get(k).is_some_and(|av| value_contains_subset(av, v))
        }),
        _ => actual == expected,
    }
}

/// True when `value` is an object containing every key in `attrs`.
///
/// An empty `attrs` list is always satisfied (including on non-objects).
pub fn value_has_attrs(value: &Value, attrs: &[String]) -> bool {
    if attrs.is_empty() {
        return true;
    }
    match value {
        Value::Object(map) => attrs.iter().all(|k| map.contains_key(k)),
        _ => false,
    }
}

#[cfg(feature = "optics")]
mod traversal_impl {
    use super::{fold_object_keys, value_has_attrs};
    use id_effect_optics::traversal::Traversal;
    use serde_json::Value;

    /// Traversal over immediate JSON object keys.
    pub fn object_keys_traversal() -> Traversal<Value, String> {
        Traversal::new(
            |value, mut f| {
                if let Value::Object(map) = value {
                    let updated: serde_json::Map<String, Value> = map
                        .into_iter()
                        .map(|(k, v)| (f(k), v))
                        .collect();
                    Value::Object(updated)
                } else {
                    value
                }
            },
            |value, visit| {
                fold_object_keys(value, |k| visit(k.to_string()));
            },
        )
    }

    /// `hasAttrs` via optics traversal — mirrors [`value_has_attrs`].
    pub fn value_has_attrs_via_traversal(value: &Value, attrs: &[String]) -> bool {
        if attrs.is_empty() {
            return true;
        }
        let keys: std::collections::HashSet<String> =
            object_keys_traversal().to_vec(value).into_iter().collect();
        attrs.iter().all(|a| keys.contains(a))
    }

    #[cfg(test)]
    mod traversal_tests {
        use super::*;

        #[test]
        fn traversal_matches_direct_has_attrs() {
            let value = serde_json::json!({"a": 1, "b": 2});
            let attrs = vec!["a".into(), "b".into()];
            assert_eq!(
                value_has_attrs_via_traversal(&value, &attrs),
                value_has_attrs(&value, &attrs)
            );
        }
    }
}

#[cfg(feature = "optics")]
pub use traversal_impl::{object_keys_traversal, value_has_attrs_via_traversal};

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn subset_is_reflexive() {
        let v = serde_json::json!({"a": {"b": 1}, "c": 2});
        assert!(value_contains_subset(&v, &v));
    }

    #[test]
    fn subset_reflexive_on_primitives() {
        let v = serde_json::json!(42);
        assert!(value_contains_subset(&v, &v));
    }

    #[test]
    fn has_attrs_empty_is_always_true() {
        let object = serde_json::json!({"a": 1});
        assert!(value_has_attrs(&object, &[]));

        let null = serde_json::json!(null);
        assert!(value_has_attrs(&null, &[]));

        let array = serde_json::json!([1, 2]);
        assert!(value_has_attrs(&array, &[]));
    }

    #[test]
    fn subset_nested_containment() {
        let actual = serde_json::json!({"a": {"b": 1, "c": 2}, "d": 3});
        let expected = serde_json::json!({"a": {"b": 1}});
        assert!(value_contains_subset(&actual, &expected));
    }

    #[test]
    fn subset_fails_on_value_mismatch() {
        let actual = serde_json::json!({"a": {"b": 1}});
        let expected = serde_json::json!({"a": {"b": 9}});
        assert!(!value_contains_subset(&actual, &expected));
    }

    #[test]
    fn has_attrs_requires_object_keys() {
        let value = serde_json::json!({"a": 1, "b": 2});
        assert!(value_has_attrs(&value, &["a".into(), "b".into()]));
        assert!(!value_has_attrs(&value, &["z".into()]));
        assert!(!value_has_attrs(&serde_json::json!(1), &["a".into()]));
    }
}
