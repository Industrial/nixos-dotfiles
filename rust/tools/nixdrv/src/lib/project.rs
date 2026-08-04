//! Selective derivation field projection to JSON.

use serde_json::{Map, Value, json};

use crate::model::Derivation;

/// Project selected fields from a derivation into a JSON object (omit missing keys).
pub fn project(drv: &Derivation, fields: &[&str]) -> Value {
    let mut out = Map::new();
    for field in fields {
        insert_field(drv, &mut out, field);
    }
    Value::Object(out)
}

fn insert_field(drv: &Derivation, out: &mut Map<String, Value>, field: &str) {
    if let Some(rest) = field.strip_prefix("env.") {
        if let Some(v) = drv.env.get(rest) {
            out.insert(field.to_string(), json!(v));
        }
        return;
    }
    match field {
        "name" => {
            if let Some(n) = drv.name() {
                out.insert("name".into(), json!(n));
            }
        }
        "outputs" => {
            if !drv.outputs.is_empty() {
                out.insert("outputs".into(), outputs_json(drv));
            }
        }
        "outPath" => {
            if let Some(p) = drv.default_out_path() {
                out.insert("outPath".into(), json!(p));
            }
        }
        "inputDrvs" => {
            if !drv.input_drvs.is_empty() {
                out.insert("inputDrvs".into(), input_drvs_json(drv));
            }
        }
        "inputSrcs" => {
            if !drv.input_srcs.is_empty() {
                out.insert("inputSrcs".into(), json!(drv.input_srcs));
            }
        }
        "system" | "platform" => {
            if !drv.platform.is_empty() {
                out.insert(field.to_string(), json!(drv.platform));
            }
        }
        "builder" => {
            if !drv.builder.is_empty() {
                out.insert("builder".into(), json!(drv.builder));
            }
        }
        "args" => {
            if !drv.args.is_empty() {
                out.insert("args".into(), json!(drv.args));
            }
        }
        "env" => {
            if !drv.env.is_empty() {
                out.insert("env".into(), json!(drv.env));
            }
        }
        _ => {}
    }
}

fn outputs_json(drv: &Derivation) -> Value {
    let mut map = Map::new();
    for (k, o) in &drv.outputs {
        map.insert(k.clone(), json!(o.path));
    }
    Value::Object(map)
}

fn input_drvs_json(drv: &Derivation) -> Value {
    let mut map = Map::new();
    for (k, v) in &drv.input_drvs {
        map.insert(k.clone(), json!(v));
    }
    Value::Object(map)
}

#[cfg(test)]
mod tests {
    use super::*;
    use nixq::value_contains_subset;
    use std::fs;
    use std::path::PathBuf;

    use crate::model::DerivationOutput;
    use crate::parse_aterm::parse_drv_aterm;

    fn fixture_path(name: &str) -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("fixtures")
            .join(name)
    }

    fn simple_drv() -> Derivation {
        let bytes = fs::read(fixture_path("simple.drv")).unwrap();
        parse_drv_aterm(&bytes).unwrap()
    }

    #[test]
    fn project_name_and_out_path() {
        let drv = simple_drv();
        let v = project(&drv, &["name", "outPath"]);
        let expected = json!({
            "name": "simple-1.0",
            "outPath": "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-simple-1.0"
        });
        assert!(value_contains_subset(&v, &expected));
    }

    #[test]
    fn project_env_dotted_key() {
        let drv = simple_drv();
        let v = project(&drv, &["env.builder"]);
        assert!(value_contains_subset(
            &v,
            &json!({ "env.builder": "/bin/sh" })
        ));
    }

    #[test]
    fn omits_missing_fields() {
        let drv = Derivation::default();
        let v = project(&drv, &["name", "outPath", "builder"]);
        assert_eq!(v, json!({}));
    }

    #[test]
    fn project_outputs_and_input_drvs() {
        let mut drv = Derivation::default();
        drv.outputs.insert(
            "out".into(),
            DerivationOutput {
                path: "/nix/store/x".into(),
                hash_algo: None,
                hash: None,
            },
        );
        drv.input_drvs
            .insert("/nix/store/d.drv".into(), vec!["out".into()]);
        let v = project(&drv, &["outputs", "inputDrvs"]);
        assert!(value_contains_subset(
            &v,
            &json!({
                "outputs": { "out": "/nix/store/x" },
                "inputDrvs": { "/nix/store/d.drv": ["out"] }
            })
        ));
    }
}
