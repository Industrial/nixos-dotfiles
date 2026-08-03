//! Load Assay-native suites: `{ name, cases = { case = { claim, ... }; }; }`.

use std::path::Path;

use anyhow::{Context, bail};
use serde_json::Value;

use crate::claims::Claim;
use crate::schema::decode_suite_cases;

/// Parse an Assay suite JSON value into named claims.
pub fn parse_assay_suite(v: &Value) -> anyhow::Result<Vec<(String, Claim)>> {
    let obj = v.as_object().context("assay suite must be an object")?;
    let cases = obj
        .get("cases")
        .and_then(|c| c.as_object())
        .context("assay suite missing cases object")?;

    decode_suite_cases(&Value::Object(cases.clone()))
        .map_err(|e| anyhow::anyhow!("{e:?}"))
}

/// Load suite from `.assay.nix` via `nix eval --json`, or from `.json`.
pub fn load_assay_suite(path: &Path) -> anyhow::Result<Vec<(String, Claim)>> {
    let v = match path.extension().and_then(|e| e.to_str()) {
        Some("json") => {
            let data = std::fs::read_to_string(path)
                .with_context(|| format!("read {}", path.display()))?;
            serde_json::from_str(&data)?
        }
        Some("nix") => nix_eval_file(path)?,
        _ => bail!("unsupported assay suite: {}", path.display()),
    };
    parse_assay_suite(&v)
}

fn nix_eval_file(path: &Path) -> anyhow::Result<Value> {
    crate::eval::nix_eval_file(path).map_err(|outcome| match outcome {
        crate::outcome::AssayOutcome::EvalError { message, .. } => {
            anyhow::anyhow!("nix eval failed: {message}")
        }
        other => anyhow::anyhow!("nix eval failed: {other:?}"),
    })
}


#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parse_eq_and_throws() {
        let v = json!({
            "name": "smoke",
            "cases": {
                "add": { "claim": "eq", "expr": "1 + 1", "expected": "2" },
                "boom": { "claim": "throws", "expr": "builtins.throw \"x\"", "pattern": "x" }
            }
        });
        let cases = parse_assay_suite(&v).expect("parse");
        assert_eq!(cases.len(), 2);
        assert!(matches!(cases[0].1, Claim::Eq { .. }) || matches!(cases[1].1, Claim::Eq { .. }));
        assert!(cases.iter().any(|(_, c)| matches!(c, Claim::Throws { .. })));
    }
}
