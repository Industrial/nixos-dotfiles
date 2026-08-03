//! Schema decode/encode for [`Claim`] and assay suite JSON via id_effect.

use std::collections::BTreeMap;

use id_effect::schema::parse::{ParseError, Schema, Unknown};
use id_effect::schema::unknown_from_serde_json;
use id_effect::schema::HasSchema;
use serde_json::Value;

use crate::claims::Claim;
use crate::compat::field_to_nix;

/// Canonical bidirectional schema for assay claim JSON objects.
pub fn claim_schema() -> Schema<Claim, Unknown, ()> {
    Schema::make(
        |u: Unknown| decode_claim_unknown(&u),
        encode_claim_unknown,
        decode_claim_unknown,
    )
}

/// Decode a claim from a JSON value.
pub fn decode_claim_json(value: &Value) -> Result<Claim, ParseError> {
    let unknown = unknown_from_serde_json(value.clone());
    claim_schema().decode_unknown(&unknown)
}

/// Encode a claim to a JSON value.
pub fn encode_claim_json(claim: &Claim) -> Value {
    unknown_to_json(&claim_schema().encode(claim.clone()))
}

/// Decode an assay suite `cases` object into named claims.
pub fn decode_suite_cases(value: &Value) -> Result<Vec<(String, Claim)>, ParseError> {
    let obj = value
        .as_object()
        .ok_or_else(|| ParseError::new("cases", "expected object"))?;
    let mut out = Vec::with_capacity(obj.len());
    for (name, case_val) in obj {
        let claim = decode_claim_json(case_val).map_err(|e| e.prefix(name))?;
        out.push((name.clone(), claim));
    }
    Ok(out)
}

fn decode_claim_unknown(value: &Unknown) -> Result<Claim, ParseError> {
    let obj = match value {
        Unknown::Object(map) => map,
        _ => return Err(ParseError::new("", "claim must be a JSON object")),
    };

    let tag = require_str(obj, "claim")?;
    match tag.as_str() {
        "eq" => Ok(Claim::Eq {
            left_expr: nix_field(obj, "expr")?,
            right_expr: nix_field(obj, "expected")?,
        }),
        "throws" => {
            let pattern = match obj.get("pattern") {
                None | Some(Unknown::Null) => None,
                Some(other) => Some(nix_field_from_unknown(other, "pattern")?),
            };
            Ok(Claim::Throws {
                expr: nix_field(obj, "expr")?,
                pattern,
            })
        }
        "subset" => Ok(Claim::Subset {
            expr: nix_field(obj, "expr")?,
            expected_subset: json_field(obj, "expected")?,
        }),
        "hasAttrs" => {
            let attrs = string_array_field(obj, "attrs")?;
            Ok(Claim::HasAttrs {
                expr: nix_field(obj, "expr")?,
                attrs,
            })
        }
        "snapshot" => Ok(Claim::Snapshot {
            name: require_str(obj, "name")?,
            expr: nix_field(obj, "expr")?,
        }),
        "forces" => Ok(Claim::Forces {
            expr: nix_field(obj, "expr")?,
            paths: string_array_field(obj, "paths")?,
        }),
        "module" => Ok(Claim::Module {
            imports_expr: nix_field(obj, "imports")?,
            args_expr: nix_field(obj, "args")?,
            expect: json_field(obj, "expect")?,
        }),
        "law" => Ok(Claim::Law {
            name: require_str(obj, "name")?,
            seed: u64_field(obj, "seed")?,
        }),
        "prop" => Ok(Claim::Prop {
            name: require_str(obj, "name")?,
            seed: u64_field(obj, "seed")?,
            trials: optional_u32_field(obj, "trials")?,
        }),
        other => Err(ParseError::new(
            "claim",
            format!("unsupported claim type: {other}"),
        )),
    }
}

fn encode_claim_unknown(claim: Claim) -> Unknown {
    let mut obj = BTreeMap::new();
    match claim {
        Claim::Eq {
            left_expr,
            right_expr,
        } => {
            obj.insert("claim".into(), Unknown::String("eq".into()));
            insert_nix_field(&mut obj, "expr", &left_expr);
            insert_nix_field(&mut obj, "expected", &right_expr);
        }
        Claim::Throws { expr, pattern } => {
            obj.insert("claim".into(), Unknown::String("throws".into()));
            insert_nix_field(&mut obj, "expr", &expr);
            if let Some(pat) = pattern {
                obj.insert("pattern".into(), Unknown::String(pat));
            }
        }
        Claim::Subset {
            expr,
            expected_subset,
        } => {
            obj.insert("claim".into(), Unknown::String("subset".into()));
            insert_nix_field(&mut obj, "expr", &expr);
            obj.insert(
                "expected".into(),
                unknown_from_serde_json(expected_subset),
            );
        }
        Claim::HasAttrs { expr, attrs } => {
            obj.insert("claim".into(), Unknown::String("hasAttrs".into()));
            insert_nix_field(&mut obj, "expr", &expr);
            obj.insert(
                "attrs".into(),
                Unknown::Array(attrs.into_iter().map(Unknown::String).collect()),
            );
        }
        Claim::Snapshot { name, expr } => {
            obj.insert("claim".into(), Unknown::String("snapshot".into()));
            obj.insert("name".into(), Unknown::String(name));
            insert_nix_field(&mut obj, "expr", &expr);
        }
        Claim::Forces { expr, paths } => {
            obj.insert("claim".into(), Unknown::String("forces".into()));
            insert_nix_field(&mut obj, "expr", &expr);
            obj.insert(
                "paths".into(),
                Unknown::Array(paths.into_iter().map(Unknown::String).collect()),
            );
        }
        Claim::Module {
            imports_expr,
            args_expr,
            expect,
        } => {
            obj.insert("claim".into(), Unknown::String("module".into()));
            insert_nix_field(&mut obj, "imports", &imports_expr);
            insert_nix_field(&mut obj, "args", &args_expr);
            obj.insert("expect".into(), unknown_from_serde_json(expect));
        }
        Claim::Law { name, seed } => {
            obj.insert("claim".into(), Unknown::String("law".into()));
            obj.insert("name".into(), Unknown::String(name));
            obj.insert(
                "seed".into(),
                Unknown::I64(i64::try_from(seed).unwrap_or(i64::MAX)),
            );
        }
        Claim::Prop { name, seed, trials } => {
            obj.insert("claim".into(), Unknown::String("prop".into()));
            obj.insert("name".into(), Unknown::String(name));
            obj.insert(
                "seed".into(),
                Unknown::I64(i64::try_from(seed).unwrap_or(i64::MAX)),
            );
            if let Some(trials) = trials {
                obj.insert("trials".into(), Unknown::I64(i64::from(trials)));
            }
        }
    }
    Unknown::Object(obj)
}

fn require_str(obj: &BTreeMap<String, Unknown>, key: &str) -> Result<String, ParseError> {
    match obj.get(key) {
        Some(Unknown::String(s)) => Ok(s.clone()),
        Some(_) => Err(ParseError::new(key, "expected string")),
        None => Err(ParseError::new(key, format!("missing field {key}"))),
    }
}

fn nix_field(obj: &BTreeMap<String, Unknown>, key: &str) -> Result<String, ParseError> {
    let value = obj
        .get(key)
        .ok_or_else(|| ParseError::new(key, format!("missing field {key}")))?;
    nix_field_from_unknown(value, key)
}

fn nix_field_from_unknown(value: &Unknown, key: &str) -> Result<String, ParseError> {
    let json = unknown_to_json(value);
    field_to_nix(&json).map_err(|err| ParseError::new(key, err.to_string()))
}

fn json_field(obj: &BTreeMap<String, Unknown>, key: &str) -> Result<Value, ParseError> {
    obj.get(key)
        .map(unknown_to_json)
        .ok_or_else(|| ParseError::new(key, format!("missing field {key}")))
}

fn string_array_field(
    obj: &BTreeMap<String, Unknown>,
    key: &str,
) -> Result<Vec<String>, ParseError> {
    match obj.get(key) {
        Some(Unknown::Array(items)) => items
            .iter()
            .enumerate()
            .map(|(idx, item)| match item {
                Unknown::String(s) => Ok(s.clone()),
                _ => Err(ParseError::new(
                    format!("{key}[{idx}]"),
                    "expected string",
                )),
            })
            .collect(),
        Some(_) => Err(ParseError::new(key, "expected array")),
        None => Err(ParseError::new(key, format!("missing field {key}"))),
    }
}

fn u64_field(obj: &BTreeMap<String, Unknown>, key: &str) -> Result<u64, ParseError> {
    match obj.get(key) {
        Some(Unknown::I64(n)) if *n >= 0 => Ok(*n as u64),
        Some(Unknown::I64(_)) => Err(ParseError::new(key, "seed must be non-negative")),
        Some(_) => Err(ParseError::new(key, "expected integer")),
        None => Err(ParseError::new(key, format!("missing field {key}"))),
    }
}

fn optional_u32_field(
    obj: &BTreeMap<String, Unknown>,
    key: &str,
) -> Result<Option<u32>, ParseError> {
    match obj.get(key) {
        None | Some(Unknown::Null) => Ok(None),
        Some(Unknown::I64(n)) if *n >= 0 && *n <= i64::from(u32::MAX) => Ok(Some(*n as u32)),
        Some(Unknown::I64(_)) => Err(ParseError::new(key, "trials out of range")),
        Some(_) => Err(ParseError::new(key, "expected integer")),
    }
}

fn insert_nix_field(obj: &mut BTreeMap<String, Unknown>, key: &str, expr: &str) {
    obj.insert(key.into(), Unknown::String(expr.to_string()));
}

fn unknown_to_json(value: &Unknown) -> Value {
    match value {
        Unknown::Null => Value::Null,
        Unknown::Bool(b) => Value::Bool(*b),
        Unknown::I64(n) => Value::Number((*n).into()),
        Unknown::F64(n) => serde_json::Number::from_f64(*n)
            .map(Value::Number)
            .unwrap_or(Value::Null),
        Unknown::String(s) => Value::String(s.clone()),
        Unknown::Array(items) => Value::Array(items.iter().map(unknown_to_json).collect()),
        Unknown::Object(map) => {
            let mut out = serde_json::Map::new();
            for (key, item) in map {
                out.insert(key.clone(), unknown_to_json(item));
            }
            Value::Object(out)
        }
    }
}

impl HasSchema for Claim {
    type A = Claim;
    type I = Unknown;
    type E = ();

    fn schema() -> Schema<Self::A, Self::I, Self::E> {
        claim_schema()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn round_trip(claim: Claim) {
        let encoded = encode_claim_json(&claim);
        let decoded = decode_claim_json(&encoded).expect("decode round-trip");
        assert_eq!(decoded, claim);
    }

    #[test]
    fn eq_claim_round_trips() {
        round_trip(Claim::Eq {
            left_expr: "1 + 1".into(),
            right_expr: "2".into(),
        });
    }

    #[test]
    fn throws_claim_round_trips_with_pattern() {
        round_trip(Claim::Throws {
            expr: "builtins.throw \"x\"".into(),
            pattern: Some("x".into()),
        });
    }

    #[test]
    fn subset_claim_round_trips() {
        round_trip(Claim::Subset {
            expr: "{ a = 1; }".into(),
            expected_subset: json!({"a": 1}),
        });
    }

    #[test]
    fn law_and_prop_claims_round_trip() {
        round_trip(Claim::Law {
            name: "merge_idempotent".into(),
            seed: 42,
        });
        round_trip(Claim::Prop {
            name: "always_pass".into(),
            seed: 7,
            trials: Some(64),
        });
    }

    #[test]
    fn fixture_suite_cases_decode_via_schema() {
        let v = json!({
            "cases": {
                "add": { "claim": "eq", "expr": "1 + 1", "expected": "2" },
                "law": { "claim": "law", "name": "merge_identity", "seed": 1 }
            }
        });
        let cases = decode_suite_cases(v.get("cases").unwrap()).expect("decode cases");
        assert_eq!(cases.len(), 2);
        assert!(matches!(cases[0].1, Claim::Eq { .. }));
        assert!(matches!(cases[1].1, Claim::Law { .. }));
    }
}
