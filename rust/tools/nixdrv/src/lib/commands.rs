//! Effect programs for nixdrv CLI commands.

use std::path::PathBuf;

use id_effect::{Effect, Needs};
use serde_json::{Map, Value, json};

use crate::ca::{FileIngestionMethod, fixed_output_path};
use crate::caps::{DrvSourceKey, NixdrvEnv};
use crate::error::InfraError;
use crate::model::Derivation;
use crate::parse_aterm::parse_drv_aterm;
use crate::project::project;
use crate::store_path::{DEFAULT_STORE_DIR, parse_store_path};

fn trim_start(bytes: &[u8]) -> &[u8] {
    match bytes.iter().position(|b| !b.is_ascii_whitespace()) {
        Some(i) => &bytes[i..],
        None => &[],
    }
}

fn is_aterm(bytes: &[u8]) -> bool {
    trim_start(bytes).starts_with(b"Derive")
}

fn read_bytes(env: &NixdrvEnv, path: &std::path::Path) -> Result<Vec<u8>, InfraError> {
    let src = Needs::<DrvSourceKey>::need(env);
    src.read(path)
}

fn parse_derivation_bytes(bytes: &[u8]) -> Result<Derivation, InfraError> {
    if is_aterm(bytes) {
        return parse_drv_aterm(bytes).map_err(InfraError::from);
    }
    let value: Value =
        serde_json::from_slice(bytes).map_err(|e| InfraError::Json(e.to_string()))?;
    Derivation::from_json(&value).map_err(InfraError::from)
}

fn read_derivation(env: &NixdrvEnv, path: &std::path::Path) -> Result<Derivation, InfraError> {
    let bytes = read_bytes(env, path)?;
    parse_derivation_bytes(&bytes)
}

pub fn derivation_to_json(drv: &Derivation) -> Value {
    let mut outputs = Map::new();
    for (k, o) in &drv.outputs {
        if o.hash_algo.is_some() || o.hash.is_some() {
            let mut obj = Map::new();
            obj.insert("path".into(), json!(o.path));
            if let Some(ha) = &o.hash_algo {
                obj.insert("hashAlgo".into(), json!(ha));
            }
            if let Some(h) = &o.hash {
                obj.insert("hash".into(), json!(h));
            }
            outputs.insert(k.clone(), Value::Object(obj));
        } else {
            outputs.insert(k.clone(), json!(o.path));
        }
    }

    let mut input_drvs = Map::new();
    for (k, v) in &drv.input_drvs {
        input_drvs.insert(k.clone(), json!(v));
    }

    let mut obj = Map::new();
    if !outputs.is_empty() {
        obj.insert("outputs".into(), Value::Object(outputs));
    }
    if !input_drvs.is_empty() {
        obj.insert("inputDrvs".into(), Value::Object(input_drvs));
    }
    if !drv.input_srcs.is_empty() {
        obj.insert("inputSrcs".into(), json!(drv.input_srcs));
    }
    if !drv.platform.is_empty() {
        obj.insert("platform".into(), json!(drv.platform));
    }
    if !drv.builder.is_empty() {
        obj.insert("builder".into(), json!(drv.builder));
    }
    if !drv.args.is_empty() {
        obj.insert("args".into(), json!(drv.args));
    }
    if !drv.env.is_empty() {
        obj.insert("env".into(), json!(drv.env));
    }
    if let Some(n) = drv.name() {
        obj.insert("name".into(), json!(n));
    }
    Value::Object(obj)
}

pub fn cmd_parse(file: PathBuf) -> Effect<Value, InfraError, NixdrvEnv> {
    Effect::new(move |env| {
        let drv = read_derivation(env, &file)?;
        Ok(derivation_to_json(&drv))
    })
}

pub fn cmd_project(file: PathBuf, fields: Vec<String>) -> Effect<Value, InfraError, NixdrvEnv> {
    Effect::new(move |env| {
        let drv = read_derivation(env, &file)?;
        let refs: Vec<&str> = fields.iter().map(String::as_str).collect();
        Ok(project(&drv, &refs))
    })
}

pub fn cmd_store_path_parse(path: String) -> Effect<Value, InfraError, NixdrvEnv> {
    Effect::new(move |_env| {
        let sp = parse_store_path(&path, DEFAULT_STORE_DIR)?;
        Ok(json!({
            "hash": sp.hash,
            "name": sp.name,
            "path": sp.full_path(DEFAULT_STORE_DIR),
        }))
    })
}

fn parse_ingestion_method(method: &str) -> Result<FileIngestionMethod, InfraError> {
    match method {
        "flat" => Ok(FileIngestionMethod::Flat),
        "recursive" => Ok(FileIngestionMethod::Recursive),
        other => Err(InfraError::Json(format!("unknown method {other}"))),
    }
}

pub fn cmd_store_path_make_fixed(
    name: String,
    method: String,
    hash_algo: String,
    digest_hex: String,
    store_dir: Option<String>,
) -> Effect<Value, InfraError, NixdrvEnv> {
    Effect::new(move |_env| {
        let method = parse_ingestion_method(&method)?;
        let digest = hex::decode(&digest_hex)
            .map_err(|e| InfraError::Json(format!("invalid digest hex: {e}")))?;
        let store_dir = store_dir.as_deref().unwrap_or(DEFAULT_STORE_DIR);
        let sp = fixed_output_path(&name, method, &hash_algo, &digest, store_dir)?;
        Ok(Value::String(sp.full_path(store_dir)))
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::caps::{DrvSourceKey, MockDrvSource, mock_providers};
    use id_effect::{Cap, Exit, FromEnv, build_env, run_test};
    use std::sync::Arc;

    const SIMPLE_DRV: &str = include_str!("../../fixtures/simple.drv");
    const SIMPLE_JSON: &str = include_str!("../../fixtures/simple.json");

    fn env_with(mock: Arc<MockDrvSource>) -> NixdrvEnv {
        let mut raw = build_env(mock_providers()).expect("env");
        raw.insert::<Cap<DrvSourceKey>>(mock as DrvSourceKey);
        NixdrvEnv::from_env(raw)
    }

    #[test]
    fn cmd_parse_aterm_fixture() {
        let mock = Arc::new(MockDrvSource::default());
        mock.set_file("simple.drv", SIMPLE_DRV.as_bytes());
        let exit = run_test(cmd_parse(PathBuf::from("simple.drv")), env_with(mock));
        match exit {
            Exit::Success(v) => {
                assert_eq!(v["name"], "simple-1.0");
                assert_eq!(v["platform"], "x86_64-linux");
                assert_eq!(
                    v["outputs"]["out"],
                    "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-simple-1.0"
                );
            }
            other => panic!("unexpected {other:?}"),
        }
    }

    #[test]
    fn cmd_parse_json_fixture() {
        let mock = Arc::new(MockDrvSource::default());
        mock.set_file("simple.json", SIMPLE_JSON.as_bytes());
        let exit = run_test(cmd_parse(PathBuf::from("simple.json")), env_with(mock));
        match exit {
            Exit::Success(v) => {
                assert_eq!(v["name"], "simple-1.0");
                assert_eq!(v["platform"], "x86_64-linux");
            }
            other => panic!("unexpected {other:?}"),
        }
    }

    #[test]
    fn cmd_project_fields() {
        let mock = Arc::new(MockDrvSource::default());
        mock.set_file("simple.drv", SIMPLE_DRV.as_bytes());
        let exit = run_test(
            cmd_project(
                PathBuf::from("simple.drv"),
                vec!["name".into(), "outPath".into()],
            ),
            env_with(mock),
        );
        match exit {
            Exit::Success(v) => {
                assert_eq!(v["name"], "simple-1.0");
                assert_eq!(
                    v["outPath"],
                    "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-simple-1.0"
                );
            }
            other => panic!("unexpected {other:?}"),
        }
    }

    #[test]
    fn cmd_store_path_parse_ok() {
        let path = "/nix/store/00000000000000000000000000000000-hello-1.0";
        let exit = run_test(
            cmd_store_path_parse(path.into()),
            env_with(Arc::new(MockDrvSource::default())),
        );
        match exit {
            Exit::Success(v) => {
                assert_eq!(v["hash"], "00000000000000000000000000000000");
                assert_eq!(v["name"], "hello-1.0");
                assert_eq!(v["path"], path);
            }
            other => panic!("unexpected {other:?}"),
        }
    }

    #[test]
    fn cmd_store_path_make_fixed_returns_path_string() {
        let digest = "11".repeat(32);
        let exit = run_test(
            cmd_store_path_make_fixed("pkg".into(), "flat".into(), "sha256".into(), digest, None),
            env_with(Arc::new(MockDrvSource::default())),
        );
        match exit {
            Exit::Success(Value::String(path)) => {
                assert!(path.starts_with("/nix/store/"));
                assert!(path.ends_with("-pkg"));
            }
            other => panic!("unexpected {other:?}"),
        }
    }

    #[test]
    fn parse_derivation_bytes_rejects_bad_json() {
        assert!(parse_derivation_bytes(b"not json").is_err());
    }
}
