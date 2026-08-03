//! Structural JSON diffs and normalized equality.

use serde_json::Value;

use crate::normalize::normalize_value;

/// Compare two values after normalization.
pub fn values_equal(a: &Value, b: &Value) -> bool {
    normalize_value(a) == normalize_value(b)
}

/// Human-readable attrpath diff; empty when `left` and `right` are equal.
pub fn structural_diff(left: &Value, right: &Value) -> String {
    if left == right {
        return String::new();
    }

    let mut lines = Vec::new();
    diff_values(left, right, "$", &mut lines);
    lines.join("\n")
}

fn diff_values(left: &Value, right: &Value, path: &str, lines: &mut Vec<String>) {
    if left == right {
        return;
    }

    match (left, right) {
        (Value::Object(left_map), Value::Object(right_map)) => {
            diff_object(left_map, right_map, path, lines);
        }
        (Value::Array(left_items), Value::Array(right_items)) => {
            diff_array(left_items, right_items, path, lines);
        }
        _ => lines.push(format!("~ {path}: {} -> {}", format_value(left), format_value(right))),
    }
}

fn diff_object(
    left: &serde_json::Map<String, Value>,
    right: &serde_json::Map<String, Value>,
    path: &str,
    lines: &mut Vec<String>,
) {
    let mut keys: Vec<&String> = left.keys().chain(right.keys()).collect();
    keys.sort();
    keys.dedup();

    for key in keys {
        let child_path = join_path(path, key);
        match (left.get(key), right.get(key)) {
            (Some(left_val), Some(right_val)) => diff_values(left_val, right_val, &child_path, lines),
            (Some(left_val), None) => lines.push(format!("- {child_path}: {}", format_value(left_val))),
            (None, Some(right_val)) => lines.push(format!("+ {child_path}: {}", format_value(right_val))),
            (None, None) => {}
        }
    }
}

fn diff_array(left: &[Value], right: &[Value], path: &str, lines: &mut Vec<String>) {
    let max_len = left.len().max(right.len());
    for index in 0..max_len {
        let child_path = format!("{path}[{index}]");
        match (left.get(index), right.get(index)) {
            (Some(left_val), Some(right_val)) => diff_values(left_val, right_val, &child_path, lines),
            (Some(left_val), None) => lines.push(format!("- {child_path}: {}", format_value(left_val))),
            (None, Some(right_val)) => lines.push(format!("+ {child_path}: {}", format_value(right_val))),
            (None, None) => {}
        }
    }
}

fn join_path(path: &str, key: &str) -> String {
    if key.chars().all(|ch| ch.is_ascii_alphanumeric() || ch == '_') {
        format!("{path}.{key}")
    } else {
        let escaped = key.replace('\\', "\\\\").replace('"', "\\\"");
        format!("{path}[\"{escaped}\"]")
    }
}

fn format_value(value: &Value) -> String {
    match value {
        Value::String(s) => format!("{s:?}"),
        other => other.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn structural_diff_empty_when_equal() {
        let value = json!({ "a": 1, "b": [2, 3] });
        assert_eq!(structural_diff(&value, &value), "");
    }

    #[test]
    fn structural_diff_reports_add_remove_and_change() {
        let left = json!({ "a": 1, "b": { "x": 1 }, "c": [1, 2] });
        let right = json!({ "a": 2, "b": { "y": 1 }, "c": [1, 3] });
        let diff = structural_diff(&left, &right);

        assert!(diff.contains("- $.b.x: 1"));
        assert!(diff.contains("+ $.b.y: 1"));
        assert!(diff.contains("~ $.a: 1 -> 2"));
        assert!(diff.contains("~ $.c[1]: 2 -> 3"));
    }

    #[test]
    fn values_equal_uses_normalization() {
        let left = json!({
            "type": "derivation",
            "outPath": "/nix/store/pkg",
            "name": "pkg",
            "builder": "/nix/store/builder",
        });
        let right = json!({
            "drvPath": "/nix/store/pkg.drv",
            "outPath": "/nix/store/pkg",
            "name": "pkg",
            "env": { "foo": "bar" },
        });

        assert!(values_equal(&left, &right));
    }

    #[test]
    fn values_equal_false_when_projections_differ() {
        let left = json!({ "outPath": "/nix/store/a", "name": "a" });
        let right = json!({ "outPath": "/nix/store/b", "name": "a" });
        assert!(!values_equal(&left, &right));
    }
}
