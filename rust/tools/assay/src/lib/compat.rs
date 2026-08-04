//! nix-unit / `lib.runTests` compatibility: load `{ name = { expr; expected; }; }` suites.

use std::path::{Path, PathBuf};

use anyhow::{Context, bail};
use serde_json::Value;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CompatCase {
    pub name: String,
    pub expr: String,
    pub expected: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CompatSuite {
    pub cases: Vec<CompatCase>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CompatClaim {
    Eq {
        left_expr: String,
        right_expr: String,
    },
}

/// Map a compat case to an equality claim (`expr` must equal `expected`).
pub fn to_claim(case: &CompatCase) -> CompatClaim {
    CompatClaim::Eq {
        left_expr: case.expr.clone(),
        right_expr: case.expected.clone(),
    }
}

/// Parse a JSON object mapping test names to `{ expr, expected }`.
pub fn parse_compat_json(v: &Value) -> anyhow::Result<CompatSuite> {
    let obj = v
        .as_object()
        .context("compat suite must be a JSON object")?;

    let mut cases = Vec::with_capacity(obj.len());
    for (name, case_val) in obj {
        let case_obj = case_val
            .as_object()
            .with_context(|| format!("case {name} must be an object"))?;
        let expr = case_obj
            .get("expr")
            .with_context(|| format!("case {name} missing expr"))?;
        let expected = case_obj
            .get("expected")
            .with_context(|| format!("case {name} missing expected"))?;
        cases.push(CompatCase {
            name: name.clone(),
            expr: field_to_nix(expr)?,
            expected: field_to_nix(expected)?,
        });
    }
    Ok(CompatSuite { cases })
}

/// Load a compat suite from `.json` or `.nix` (nix-unit / runTests shape).
pub fn load_compat_suite(path: &Path) -> anyhow::Result<CompatSuite> {
    match path.extension().and_then(|e| e.to_str()) {
        Some("json") => load_json_file(path),
        Some("nix") => load_nix_compat_suite(path),
        _ => bail!("unsupported compat suite format: {}", path.display()),
    }
}

fn load_json_file(path: &Path) -> anyhow::Result<CompatSuite> {
    let data = std::fs::read_to_string(path).with_context(|| format!("read {}", path.display()))?;
    let v: Value = serde_json::from_str(&data)?;
    parse_compat_json(&v)
}

fn sidecar_json_path(nix_path: &Path) -> PathBuf {
    nix_path.with_extension("json")
}

fn load_nix_compat_suite(path: &Path) -> anyhow::Result<CompatSuite> {
    match try_nix_eval(path) {
        Ok(suite) => Ok(suite),
        Err(primary) => {
            let sidecar = sidecar_json_path(path);
            if sidecar.is_file() {
                load_json_file(&sidecar)
            } else {
                Err(primary)
            }
        }
    }
}

fn try_nix_eval(path: &Path) -> anyhow::Result<CompatSuite> {
    let v = crate::eval::nix_eval_file(path).map_err(|outcome| match outcome {
        crate::outcome::AssayOutcome::EvalError { message, .. } => {
            anyhow::anyhow!("nix eval failed: {message}")
        }
        other => anyhow::anyhow!("nix eval failed: {other:?}"),
    })?;
    parse_compat_json(&v)
}

fn nix_string_literal(s: &str) -> String {
    let escaped = s.replace('\\', "\\\\").replace('"', "\\\"");
    format!("\"{escaped}\"")
}

fn is_valid_nix_ident(s: &str) -> bool {
    if s.is_empty() {
        return false;
    }
    let mut chars = s.chars();
    match chars.next() {
        Some(c) if c.is_ascii_alphabetic() || c == '_' => {}
        _ => return false,
    }
    chars.all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-' || c == '\'')
}

fn nix_attr_name(s: &str) -> String {
    if is_valid_nix_ident(s) {
        s.to_string()
    } else {
        nix_string_literal(s)
    }
}

/// Convert a JSON field to a Nix expression string (strings pass through as source).
///
/// Used for nix-unit compat suites where `expr` / `expected` strings are Nix source.
pub fn field_to_nix(v: &Value) -> anyhow::Result<String> {
    match v {
        Value::String(s) => Ok(s.clone()),
        other => Ok(value_to_nix_expr(other)),
    }
}

/// Serialize a `nix eval --json` value as a Nix expression (including strings).
pub fn json_value_to_nix(v: &Value) -> String {
    value_to_nix_expr(v)
}

fn value_to_nix_expr(v: &Value) -> String {
    match v {
        Value::Null => "null".into(),
        Value::Bool(b) => b.to_string(),
        Value::Number(n) => n.to_string(),
        Value::String(s) => nix_string_literal(s),
        Value::Array(items) => {
            let inner: Vec<_> = items.iter().map(value_to_nix_expr).collect();
            format!("[{}]", inner.join(" "))
        }
        Value::Object(map) => {
            if map.is_empty() {
                return "{}".into();
            }
            let inner: Vec<_> = map
                .iter()
                .map(|(k, v)| format!("{} = {}", nix_attr_name(k), value_to_nix_expr(v)))
                .collect();
            format!("{{ {}; }}", inner.join("; "))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parse_compat_json_five_cases() {
        let v = json!({
            "trim_identity": { "expr": "\"hi\"", "expected": "\"hi\"" },
            "list_len": { "expr": "builtins.length [1 2 3]", "expected": "3" },
            "bool_and": { "expr": "true && false", "expected": "false" },
            "json_number": { "expr": 42, "expected": 42 },
            "json_list": { "expr": [1, 2, 3], "expected": "[1 2 3]" },
        });
        let suite = parse_compat_json(&v).expect("parse");
        assert_eq!(suite.cases.len(), 5);

        let by_name: std::collections::HashMap<_, _> =
            suite.cases.iter().map(|c| (c.name.as_str(), c)).collect();

        assert_eq!(by_name["trim_identity"].expr, "\"hi\"");
        assert_eq!(by_name["list_len"].expr, "builtins.length [1 2 3]");
        assert_eq!(by_name["bool_and"].expected, "false");
        assert_eq!(by_name["json_number"].expr, "42");
        assert_eq!(by_name["json_number"].expected, "42");
        assert_eq!(by_name["json_list"].expr, "[1 2 3]");
    }

    #[test]
    fn to_claim_maps_eq() {
        let case = CompatCase {
            name: "x".into(),
            expr: "1 + 1".into(),
            expected: "2".into(),
        };
        assert_eq!(
            to_claim(&case),
            CompatClaim::Eq {
                left_expr: "1 + 1".into(),
                right_expr: "2".into(),
            }
        );
    }

    #[test]
    fn load_compat_suite_from_fixture_json() {
        let path = Path::new(env!("CARGO_MANIFEST_DIR")).join("fixtures/compat/suite.json");
        let suite = load_compat_suite(&path).expect("load suite.json");
        assert!(suite.cases.len() >= 5);
    }
    #[test]
    fn json_value_to_nix_covers_types() {
        assert_eq!(json_value_to_nix(&json!(null)), "null");
        assert_eq!(json_value_to_nix(&json!(true)), "true");
        assert_eq!(json_value_to_nix(&json!(1)), "1");
        assert_eq!(json_value_to_nix(&json!("hi")), "\"hi\"");
        assert_eq!(json_value_to_nix(&json!([])), "[]");
        assert_eq!(json_value_to_nix(&json!({})), "{}");
    }

    #[test]
    fn load_compat_unsupported_extension() {
        let path = std::env::temp_dir().join("assay-bad.ext");
        std::fs::write(&path, "{}").unwrap();
        assert!(load_compat_suite(&path).is_err());
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn parse_compat_json_rejects_non_object() {
        assert!(parse_compat_json(&json!([])).is_err());
    }

    #[test]
    fn parse_compat_json_rejects_bad_case_shape() {
        assert!(parse_compat_json(&json!({"x": "not-object"})).is_err());
        assert!(parse_compat_json(&json!({"x": {"expected": "1"}})).is_err());
        assert!(parse_compat_json(&json!({"x": {"expr": "1"}})).is_err());
    }

    #[test]
    fn is_valid_nix_ident_and_attr_name() {
        assert!(!is_valid_nix_ident(""));
        assert!(!is_valid_nix_ident("1bad"));
        assert!(is_valid_nix_ident("foo-bar"));
        assert!(is_valid_nix_ident("_x"));
        assert!(!is_valid_nix_ident("has space"));
        assert!(!is_valid_nix_ident("good@bad"));
        assert!(!is_valid_nix_ident("ab.c"));
        assert_eq!(nix_attr_name("valid"), "valid");
        assert_eq!(nix_attr_name("bad key"), "\"bad key\"");
    }

    #[test]
    fn json_value_to_nix_nested_and_escaped() {
        let nested = json!({"a": 1, "bad key": [true, "x\"y"]});
        let rendered = json_value_to_nix(&nested);
        assert!(rendered.contains("a = 1"));
        assert!(rendered.contains("\"bad key\""));
        assert!(rendered.contains("true"));
        assert!(rendered.contains("x\\\"y"));
        assert!(nix_string_literal("a\"b").contains("\\\""));
    }

    #[test]
    fn field_to_nix_accepts_json_literals() {
        assert_eq!(field_to_nix(&json!("expr")).unwrap(), "expr");
        assert_eq!(field_to_nix(&json!(42)).unwrap(), "42");
    }

    #[test]
    fn load_nix_compat_suite_propagates_error_without_sidecar() {
        let dir = std::env::temp_dir().join(format!(
            "assay-compat-no-sidecar-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let nix_path = dir.join("suite.nix");
        std::fs::write(&nix_path, "invalid nix {{{").unwrap();
        assert!(load_compat_suite(&nix_path).is_err());
        let _ = std::fs::remove_dir_all(dir);
    }

    #[test]
    fn load_nix_compat_suite_uses_sidecar_json() {
        let dir = std::env::temp_dir().join(format!(
            "assay-compat-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        let nix_path = dir.join("suite.nix");
        let json_path = dir.join("suite.json");
        std::fs::write(&nix_path, "invalid nix {{{").unwrap();
        std::fs::write(&json_path, r#"{"sidecar": {"expr": "1", "expected": "1"}}"#).unwrap();
        let suite = load_compat_suite(&nix_path).expect("sidecar fallback");
        assert_eq!(suite.cases.len(), 1);
        assert_eq!(suite.cases[0].name, "sidecar");
        let _ = std::fs::remove_dir_all(dir);
    }
}
