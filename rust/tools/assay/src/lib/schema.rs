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
        "eq" => {
            if obj.contains_key("actual") {
                Ok(Claim::EqValues {
                    left: json_field(obj, "actual")?,
                    right: json_field(obj, "expected")?,
                })
            } else {
                Ok(Claim::Eq {
                    left_expr: source_field(obj, "expr")?,
                    right_expr: source_field(obj, "expected")?,
                })
            }
        }
        "throws" => {
            let pattern = match obj.get("pattern") {
                None | Some(Unknown::Null) => None,
                Some(other) => Some(source_field_from_unknown(other, "pattern")?),
            };
            Ok(Claim::Throws {
                expr: source_field(obj, "expr")?,
                pattern,
            })
        }
        "subset" => {
            if obj.contains_key("actual") {
                Ok(Claim::SubsetValues {
                    actual: json_field(obj, "actual")?,
                    expected_subset: json_field(obj, "expected")?,
                })
            } else {
                Ok(Claim::Subset {
                    expr: source_field(obj, "expr")?,
                    expected_subset: json_field(obj, "expected")?,
                })
            }
        }
        "hasAttrs" => {
            let attrs = string_array_field(obj, "attrs")?;
            if obj.contains_key("actual") {
                Ok(Claim::HasAttrsValues {
                    actual: json_field(obj, "actual")?,
                    attrs,
                })
            } else {
                Ok(Claim::HasAttrs {
                    expr: source_field(obj, "expr")?,
                    attrs,
                })
            }
        }
        "snapshot" => Ok(Claim::Snapshot {
            name: require_str(obj, "name")?,
            expr: source_field(obj, "expr")?,
        }),
        "forces" => Ok(Claim::Forces {
            expr: source_field(obj, "expr")?,
            paths: string_array_field(obj, "paths")?,
        }),
        "module" => Ok(Claim::Module {
            imports_expr: source_field(obj, "imports")?,
            args_expr: source_field(obj, "args")?,
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
        Claim::EqValues { left, right } => {
            obj.insert("claim".into(), Unknown::String("eq".into()));
            obj.insert("actual".into(), unknown_from_serde_json(left));
            obj.insert("expected".into(), unknown_from_serde_json(right));
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
        Claim::SubsetValues {
            actual,
            expected_subset,
        } => {
            obj.insert("claim".into(), Unknown::String("subset".into()));
            obj.insert("actual".into(), unknown_from_serde_json(actual));
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
        Claim::HasAttrsValues { actual, attrs } => {
            obj.insert("claim".into(), Unknown::String("hasAttrs".into()));
            obj.insert("actual".into(), unknown_from_serde_json(actual));
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

fn source_field(obj: &BTreeMap<String, Unknown>, key: &str) -> Result<String, ParseError> {
    let value = obj
        .get(key)
        .ok_or_else(|| ParseError::new(key, format!("missing field {key}")))?;
    source_field_from_unknown(value, key)
}

fn source_field_from_unknown(value: &Unknown, key: &str) -> Result<String, ParseError> {
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
    fn eq_values_claim_round_trips() {
        round_trip(Claim::EqValues {
            left: json!(2),
            right: json!(2),
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
        round_trip(Claim::Prop {
            name: "always_pass".into(),
            seed: 8,
            trials: None,
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
    #[test]
    fn subset_values_claim_round_trips() {
        round_trip(Claim::SubsetValues {
            actual: json!({"a": 1}),
            expected_subset: json!({"a": 1}),
        });
    }

    #[test]
    fn hasattrs_values_claim_round_trips() {
        round_trip(Claim::HasAttrsValues {
            actual: json!({"a": 1}),
            attrs: vec!["a".into()],
        });
    }

    #[test]
    fn decode_claim_json_rejects_unknown() {
        assert!(decode_claim_json(&json!({"claim": "nope"})).is_err());
        assert!(decode_claim_json(&json!({"claim": "eq"})).is_err());
    }

    #[test]
    fn value_mode_eq_uses_actual_key() {
        let encoded = encode_claim_json(&Claim::EqValues {
            left: json!(1),
            right: json!(2),
        });
        assert!(encoded.get("actual").is_some());
        let decoded = decode_claim_json(&encoded).expect("decode");
        assert!(matches!(decoded, Claim::EqValues { .. }));
    }

    #[test]
    fn throws_without_pattern_round_trips() {
        round_trip(Claim::Throws {
            expr: "builtins.throw \"x\"".into(),
            pattern: None,
        });
    }

    #[test]
    fn snapshot_forces_module_round_trip() {
        round_trip(Claim::Snapshot {
            name: "snap".into(),
            expr: "1".into(),
        });
        round_trip(Claim::Forces {
            expr: "x".into(),
            paths: vec!["p".into()],
        });
        round_trip(Claim::Module {
            imports_expr: "[]".into(),
            args_expr: "{}".into(),
            expect: json!({"ok": true}),
        });
    }

    #[test]
    fn hasattrs_expr_mode_round_trips() {
        round_trip(Claim::HasAttrs {
            expr: "{ a = 1; }".into(),
            attrs: vec!["a".into()],
        });
    }

    #[test]
    fn decode_suite_cases_rejects_non_object() {
        assert!(decode_suite_cases(&json!([])).is_err());
    }

    #[test]
    fn decode_field_helper_errors() {
        use id_effect::schema::unknown_from_serde_json;
        let bad = unknown_from_serde_json(json!({"claim": 1}));
        assert!(decode_claim_json(&json!({"claim": 1})).is_err());
        assert!(decode_claim_json(&json!({"claim": "eq"})).is_err());
        assert!(decode_claim_json(&json!({"claim": "law", "name": "x"})).is_err());
        assert!(decode_claim_json(&json!({"claim": "prop", "name": "x", "seed": -1})).is_err());
        assert!(decode_claim_json(&json!({"claim": "prop", "name": "x", "seed": 1, "trials": 9999999999i64})).is_err());
        assert!(decode_claim_json(&json!({"claim": "prop", "name": "x", "seed": 1, "trials": "lots"})).is_err());
        assert!(decode_claim_json(&json!({"claim": "hasAttrs", "expr": "x", "attrs": [1]})).is_err());
        assert!(decode_claim_json(&json!({"claim": "subset", "actual": {}})).is_err());
        let _ = bad;
    }

    #[test]
    fn claim_schema_has_schema_trait() {
        let _ = Claim::schema();
    }

    #[test]
    fn unknown_to_json_f64_nan_becomes_null() {
        use id_effect::schema::Unknown;
        let nan = Unknown::F64(f64::NAN);
        assert_eq!(unknown_to_json(&nan), Value::Null);
    }

    #[test]
    fn unknown_to_json_covers_all_variants() {
        use id_effect::schema::Unknown;
        assert_eq!(unknown_to_json(&Unknown::Bool(true)), Value::Bool(true));
        assert_eq!(unknown_to_json(&Unknown::I64(3)), Value::Number(3.into()));
        assert_eq!(
            unknown_to_json(&Unknown::F64(1.5)),
            Value::Number(serde_json::Number::from_f64(1.5).unwrap())
        );
        assert_eq!(
            unknown_to_json(&Unknown::Array(vec![Unknown::Null])),
            json!([null])
        );
        assert_eq!(
            unknown_to_json(&Unknown::Object(BTreeMap::from([(
                "k".into(),
                Unknown::String("v".into()),
            )]))),
            json!({"k": "v"})
        );
    }

    #[test]
    fn law_seed_max_encodes_as_i64_max() {
        let encoded = encode_claim_json(&Claim::Law {
            name: "merge_identity".into(),
            seed: u64::MAX,
        });
        assert_eq!(encoded["seed"], json!(i64::MAX));
    }

    #[test]
    fn prop_optional_trials_null_and_valid() {
        let without = decode_claim_json(&json!({
            "claim": "prop",
            "name": "gen_int",
            "seed": 1
        }))
        .expect("decode");
        assert!(matches!(without, Claim::Prop { trials: None, .. }));
        let encoded = encode_claim_json(&without);
        assert!(encoded.get("trials").is_none());

        let with_valid = decode_claim_json(&json!({
            "claim": "prop",
            "name": "gen_int",
            "seed": 1,
            "trials": 42
        }))
        .expect("decode");
        assert!(matches!(with_valid, Claim::Prop { trials: Some(42), .. }));
    }

    #[test]
    fn throws_null_pattern_decodes_as_none() {
        let decoded = decode_claim_json(&json!({
            "claim": "throws",
            "expr": "builtins.throw \"x\"",
            "pattern": null
        }))
        .expect("decode");
        assert!(matches!(decoded, Claim::Throws { pattern: None, .. }));
    }

}
