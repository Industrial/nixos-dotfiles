//! JSON derivation parsing (`nix derivation show`, bare, eval-like).

use std::collections::BTreeMap;

use serde_json::{Map, Value};

use crate::error::ParseError;
use crate::model::{Derivation, DerivationOutput};

type InputDrvs = BTreeMap<String, Vec<String>>;
type ParsedInputs = (InputDrvs, Vec<String>);

impl Derivation {
    /// Parse a derivation from JSON (`nix derivation show`, bare object, or eval projection).
    pub fn from_json(value: &Value) -> Result<Self, ParseError> {
        let obj = unwrap_derivation_object(value)?;
        if is_eval_like(obj) {
            return synthesize_eval_derivation(obj);
        }
        parse_bare_derivation(obj)
    }
}

fn unwrap_derivation_object(value: &Value) -> Result<&Map<String, Value>, ParseError> {
    match value {
        Value::Object(map) if is_wrapped_show(map) => {
            let inner = map.values().next().ok_or_else(|| ParseError::Invalid {
                offset: 0,
                what: "wrapped derivation".into(),
                message: "empty wrapper object".into(),
            })?;
            inner.as_object().ok_or_else(|| ParseError::Invalid {
                offset: 0,
                what: "wrapped derivation".into(),
                message: "expected inner object".into(),
            })
        }
        Value::Object(map) => Ok(map),
        _ => Err(ParseError::Invalid {
            offset: 0,
            what: "derivation".into(),
            message: "expected JSON object".into(),
        }),
    }
}

fn is_wrapped_show(map: &Map<String, Value>) -> bool {
    map.len() == 1
        && map
            .keys()
            .next()
            .is_some_and(|k| k.starts_with("/nix/store/") && k.ends_with(".drv"))
}

fn is_eval_like(map: &Map<String, Value>) -> bool {
    map.get("type").and_then(Value::as_str) == Some("derivation")
        || (map.contains_key("outPath") && map.contains_key("drvPath"))
}

fn synthesize_eval_derivation(map: &Map<String, Value>) -> Result<Derivation, ParseError> {
    let out_path = string_field(map, "outPath")?;
    let name = string_field_opt(map, "name");
    let mut outputs = BTreeMap::new();
    outputs.insert(
        "out".into(),
        DerivationOutput {
            path: out_path.clone(),
            hash_algo: None,
            hash: None,
        },
    );
    let mut env = BTreeMap::new();
    if let Some(n) = &name {
        env.insert("name".into(), n.clone());
        env.insert("out".into(), out_path);
    }
    Ok(Derivation {
        outputs,
        input_drvs: BTreeMap::new(),
        input_srcs: vec![],
        platform: string_field_opt(map, "system").unwrap_or_else(|| "unknown".into()),
        builder: String::new(),
        args: vec![],
        env,
        name,
    })
}

fn parse_bare_derivation(map: &Map<String, Value>) -> Result<Derivation, ParseError> {
    let outputs = parse_outputs(map)?;
    let (input_drvs, input_srcs) = parse_inputs(map)?;
    let platform = string_field_opt(map, "system")
        .or_else(|| string_field_opt(map, "platform"))
        .unwrap_or_default();
    let builder = string_field_opt(map, "builder").unwrap_or_default();
    let args = parse_string_array(map.get("args"))?;
    let env = parse_string_map(map.get("env"))?;
    let name = string_field_opt(map, "name").or_else(|| env.get("name").cloned());
    Ok(Derivation {
        outputs,
        input_drvs,
        input_srcs,
        platform,
        builder,
        args,
        env,
        name,
    })
}

fn parse_outputs(
    map: &Map<String, Value>,
) -> Result<BTreeMap<String, DerivationOutput>, ParseError> {
    let mut outputs = BTreeMap::new();
    let Some(Value::Object(out_map)) = map.get("outputs") else {
        return Ok(outputs);
    };
    for (key, val) in out_map {
        outputs.insert(key.clone(), parse_output_entry(val)?);
    }
    Ok(outputs)
}

fn parse_output_entry(val: &Value) -> Result<DerivationOutput, ParseError> {
    match val {
        Value::String(path) => Ok(DerivationOutput {
            path: path.clone(),
            hash_algo: None,
            hash: None,
        }),
        Value::Object(obj) => Ok(DerivationOutput {
            path: string_field(obj, "path")?,
            hash_algo: string_field_opt(obj, "hashAlgo"),
            hash: string_field_opt(obj, "hash"),
        }),
        _ => Err(ParseError::Invalid {
            offset: 0,
            what: "output".into(),
            message: "expected string or object".into(),
        }),
    }
}

fn parse_inputs(map: &Map<String, Value>) -> Result<ParsedInputs, ParseError> {
    if let Some(Value::Object(inputs)) = map.get("inputs") {
        let drvs = parse_input_drvs_json(inputs.get("drvs"))?;
        let srcs = parse_string_array(inputs.get("srcs"))?;
        return Ok((drvs, srcs));
    }
    let drvs = parse_input_drvs_json(map.get("inputDrvs"))?;
    let srcs = parse_string_array(map.get("inputSrcs"))?;
    Ok((drvs, srcs))
}

fn parse_input_drvs_json(val: Option<&Value>) -> Result<InputDrvs, ParseError> {
    let mut map = BTreeMap::new();
    let Some(Value::Object(obj)) = val else {
        return Ok(map);
    };
    for (path, outs) in obj {
        map.insert(path.clone(), parse_string_array(Some(outs))?);
    }
    Ok(map)
}

fn parse_string_array(val: Option<&Value>) -> Result<Vec<String>, ParseError> {
    let Some(Value::Array(items)) = val else {
        return Ok(vec![]);
    };
    items
        .iter()
        .map(|v| {
            v.as_str()
                .map(str::to_string)
                .ok_or_else(|| ParseError::Invalid {
                    offset: 0,
                    what: "array".into(),
                    message: "expected string element".into(),
                })
        })
        .collect()
}

fn parse_string_map(val: Option<&Value>) -> Result<BTreeMap<String, String>, ParseError> {
    let mut map = BTreeMap::new();
    let Some(Value::Object(obj)) = val else {
        return Ok(map);
    };
    for (k, v) in obj {
        let s = v.as_str().ok_or_else(|| ParseError::Invalid {
            offset: 0,
            what: "env".into(),
            message: format!("expected string for {k}"),
        })?;
        map.insert(k.clone(), s.to_string());
    }
    Ok(map)
}

fn string_field(map: &Map<String, Value>, key: &str) -> Result<String, ParseError> {
    string_field_opt(map, key).ok_or_else(|| ParseError::Invalid {
        offset: 0,
        what: key.into(),
        message: "missing or non-string field".into(),
    })
}

fn string_field_opt(map: &Map<String, Value>, key: &str) -> Option<String> {
    map.get(key).and_then(Value::as_str).map(str::to_string)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::PathBuf;

    fn fixture_path(name: &str) -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("fixtures")
            .join(name)
    }

    #[test]
    fn from_bare_json_fixture() {
        let text = fs::read_to_string(fixture_path("simple.json")).unwrap();
        let v: Value = serde_json::from_str(&text).unwrap();
        let drv = Derivation::from_json(&v).unwrap();
        assert_eq!(drv.name(), Some("simple-1.0"));
        assert_eq!(drv.platform, "x86_64-linux");
    }

    #[test]
    fn from_wrapped_show_json() {
        let v = serde_json::json!({
            "/nix/store/abc.drv": {
                "outputs": { "out": "/nix/store/out" },
                "inputDrvs": {},
                "inputSrcs": [],
                "system": "x86_64-linux",
                "builder": "/bin/sh",
                "args": [],
                "env": { "name": "pkg" }
            }
        });
        let drv = Derivation::from_json(&v).unwrap();
        assert_eq!(drv.name(), Some("pkg"));
    }

    #[test]
    fn from_eval_like_json() {
        let v = serde_json::json!({
            "type": "derivation",
            "outPath": "/nix/store/out",
            "drvPath": "/nix/store/x.drv",
            "name": "hello"
        });
        let drv = Derivation::from_json(&v).unwrap();
        assert_eq!(drv.default_out_path(), Some("/nix/store/out"));
        assert_eq!(drv.name(), Some("hello"));
    }

    #[test]
    fn v4_inputs_style() {
        let v = serde_json::json!({
            "outputs": { "out": "/nix/store/out" },
            "inputs": {
                "drvs": { "/nix/store/dep.drv": ["out"] },
                "srcs": ["/nix/store/src"]
            },
            "system": "aarch64-linux",
            "builder": "/bin/sh",
            "args": [],
            "env": {}
        });
        let drv = Derivation::from_json(&v).unwrap();
        assert_eq!(drv.input_srcs, vec!["/nix/store/src"]);
        assert_eq!(drv.input_drvs.len(), 1);
    }
}
