//! Derivation-safe JSON normalization with depth and size budgets.

use serde_json::{Map, Value, json};

const MAX_DEPTH: usize = 64;
const MAX_SIZE: usize = 1_000_000;

/// Normalize a JSON value for comparison: project derivations, recurse, enforce budgets.
pub fn normalize_value(v: &Value) -> Value {
    normalize_inner(v, 0)
}

fn normalize_inner(v: &Value, depth: usize) -> Value {
    if depth > MAX_DEPTH {
        return budget_exceeded("depth");
    }
    if estimate_size(v) > MAX_SIZE {
        return budget_exceeded("size");
    }

    match v {
        Value::Object(map) => {
            if is_derivation_like(map) {
                return project_derivation(map);
            }
            let mut out = Map::new();
            for (key, val) in map {
                out.insert(key.clone(), normalize_inner(val, depth + 1));
            }
            Value::Object(out)
        }
        Value::Array(items) => Value::Array(
            items
                .iter()
                .map(|item| normalize_inner(item, depth + 1))
                .collect(),
        ),
        _ => v.clone(),
    }
}

fn is_derivation_like(map: &Map<String, Value>) -> bool {
    if map.get("type").and_then(Value::as_str) == Some("derivation") {
        return true;
    }
    map
        .get("outPath")
        .is_some_and(Value::is_string)
        || map.get("drvPath").is_some_and(Value::is_string)
}

fn project_derivation(map: &Map<String, Value>) -> Value {
    let mut out = Map::new();
    out.insert("type".into(), Value::String("derivation".into()));
    if let Some(path) = map.get("outPath").filter(|value| value.is_string()) {
        out.insert("outPath".into(), path.clone());
    }
    if let Some(name) = map.get("name").filter(|value| value.is_string()) {
        out.insert("name".into(), name.clone());
    }
    Value::Object(out)
}

fn budget_exceeded(reason: &str) -> Value {
    json!({
        "type": "budget_exceeded",
        "reason": reason,
    })
}

fn estimate_size(v: &Value) -> usize {
    estimate_size_inner(v, 0)
}

fn estimate_size_inner(v: &Value, depth: usize) -> usize {
    if depth > MAX_DEPTH {
        return 48;
    }
    match v {
        Value::Null => 4,
        Value::Bool(true) => 4,
        Value::Bool(false) => 5,
        Value::Number(n) => n.to_string().len(),
        Value::String(s) => s.len().saturating_add(2),
        Value::Array(items) => {
            let body: usize = items
                .iter()
                .map(|item| estimate_size_inner(item, depth + 1))
                .sum();
            body.saturating_add(2).saturating_add(items.len())
        }
        Value::Object(map) => {
            let body: usize = map
                .iter()
                .map(|(key, val)| {
                    key.len()
                        .saturating_add(3)
                        .saturating_add(estimate_size_inner(val, depth + 1))
                })
                .sum();
            body.saturating_add(2).saturating_add(map.len())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn deep_derivation_shell(depth: usize, out_path: &str) -> Value {
        let mut inner = json!({
            "outPath": out_path,
            "drvPath": "/nix/store/abc.drv",
            "name": "hello",
            "builder": "/nix/store/builder.sh",
            "args": ["-c", "echo hi"],
        });
        for i in 0..depth {
            inner = json!({
                "outPath": out_path,
                "drvPath": format!("/nix/store/layer-{i}.drv"),
                "name": "hello",
                "nested": inner,
                "meta": { "layer": i },
            });
        }
        inner
    }

    #[test]
    fn derivation_eq_does_not_overflow() {
        let left = deep_derivation_shell(200, "/nix/store/hello-left");
        let right = deep_derivation_shell(200, "/nix/store/hello-left");

        let normalized_left = normalize_value(&left);
        let normalized_right = normalize_value(&right);

        assert_eq!(
            normalized_left,
            json!({
                "type": "derivation",
                "outPath": "/nix/store/hello-left",
                "name": "hello",
            })
        );
        assert_eq!(normalized_left, normalized_right);
    }

    #[test]
    fn derivation_projection_ignores_heavy_internals() {
        let a = json!({
            "type": "derivation",
            "outPath": "/nix/store/pkg-a",
            "name": "pkg",
            "builder": "/nix/store/builder",
            "env": { "CFLAGS": "-O2", "nested": { "deep": [1, 2, 3] } },
        });
        let b = json!({
            "drvPath": "/nix/store/pkg-b.drv",
            "outPath": "/nix/store/pkg-a",
            "name": "pkg",
            "builder": "/nix/store/other-builder",
            "env": { "CFLAGS": "-O0" },
        });

        assert_eq!(normalize_value(&a), normalize_value(&b));
    }

    #[test]
    fn depth_budget_returns_marker() {
        let mut nested = json!(1);
        for _ in 0..80 {
            nested = json!({ "child": nested });
        }
        let normalized = normalize_value(&nested);
        let serialized = serde_json::to_string(&normalized).expect("serialize");
        assert!(serialized.contains("budget_exceeded"));
        assert!(serialized.contains("depth"));
    }

    #[test]
    fn recurses_through_arrays_and_objects() {
        let input = json!({
            "items": [
                { "outPath": "/nix/store/a", "name": "a" },
                { "x": 1 },
            ],
            "meta": { "count": 2 },
        });
        assert_eq!(
            normalize_value(&input),
            json!({
                "items": [
                    { "type": "derivation", "outPath": "/nix/store/a", "name": "a" },
                    { "x": 1 },
                ],
                "meta": { "count": 2 },
            })
        );
    }
}
