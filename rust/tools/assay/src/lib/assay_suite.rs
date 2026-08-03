//! Load Assay-native suites: `{ name, cases = { case = { claim, ... }; }; }`.

use std::path::Path;
use std::process::Command;

use anyhow::{Context, bail};
use serde_json::Value;

use crate::claims::Claim;
use crate::compat::field_to_nix;

/// Parse an Assay suite JSON value into named claims.
pub fn parse_assay_suite(v: &Value) -> anyhow::Result<Vec<(String, Claim)>> {
    let obj = v.as_object().context("assay suite must be an object")?;
    let cases = obj
        .get("cases")
        .and_then(|c| c.as_object())
        .context("assay suite missing cases object")?;

    let mut out = Vec::with_capacity(cases.len());
    for (name, case_val) in cases {
        out.push((name.clone(), claim_from_json(case_val)?));
    }
    Ok(out)
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
    let output = Command::new("nix")
        .args(["eval", "--impure", "--file"])
        .arg(path)
        .arg("--json")
        .output()
        .with_context(|| format!("nix eval {}", path.display()))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        bail!("nix eval failed: {stderr}");
    }
    Ok(serde_json::from_slice(&output.stdout)?)
}

fn claim_from_json(v: &Value) -> anyhow::Result<Claim> {
    let obj = v.as_object().context("claim must be an object")?;
    let claim = obj
        .get("claim")
        .and_then(|c| c.as_str())
        .unwrap_or("eq");

    match claim {
        "eq" => {
            let left = obj.get("expr").context("eq missing expr")?;
            let right = obj.get("expected").context("eq missing expected")?;
            Ok(Claim::Eq {
                left_expr: field_to_nix(left)?,
                right_expr: field_to_nix(right)?,
            })
        }
        "throws" => {
            let expr = obj.get("expr").context("throws missing expr")?;
            let pattern = match obj.get("pattern") {
                None | Some(Value::Null) => None,
                Some(p) => Some(field_to_nix(p)?.trim_matches('"').to_string()),
            };
            Ok(Claim::Throws {
                expr: field_to_nix(expr)?,
                pattern,
            })
        }
        "subset" => {
            let expr = obj.get("expr").context("subset missing expr")?;
            let expected = obj
                .get("expected")
                .cloned()
                .context("subset missing expected")?;
            Ok(Claim::Subset {
                expr: field_to_nix(expr)?,
                expected_subset: expected,
            })
        }
        "hasAttrs" => {
            let expr = obj.get("expr").context("hasAttrs missing expr")?;
            let attrs = obj
                .get("attrs")
                .and_then(|a| a.as_array())
                .context("hasAttrs missing attrs array")?
                .iter()
                .filter_map(|v| v.as_str().map(str::to_string))
                .collect();
            Ok(Claim::HasAttrs {
                expr: field_to_nix(expr)?,
                attrs,
            })
        }
        other => bail!("unsupported claim type: {other}"),
    }
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
