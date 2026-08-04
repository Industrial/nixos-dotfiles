//! Effect programs for CLI commands.

use std::path::PathBuf;

use id_effect::{Effect, Needs};
use serde_json::Value;

use crate::caps::{JsonSourceKey, NixqEnv};
use crate::diff::{structural_diff, values_equal};
use crate::error::{InfraError, PathError, PredicateResult};
use crate::force_path::force_paths;
use crate::normalize::normalize_value;
use crate::optics::{value_contains_subset, value_has_attrs};
use crate::path::{get_at_path, parse_attrpath};

fn parse_json(bytes: &[u8]) -> Result<Value, InfraError> {
    serde_json::from_slice(bytes).map_err(|e| InfraError::Json(e.to_string()))
}

fn read_value(env: &NixqEnv, input: &std::path::Path) -> Result<Value, InfraError> {
    let src = Needs::<JsonSourceKey>::need(env);
    let bytes = src.read(input)?;
    parse_json(&bytes)
}

pub fn load_json(input: PathBuf) -> Effect<Value, InfraError, NixqEnv> {
    Effect::new(move |env| read_value(env, &input))
}

pub fn cmd_get(input: PathBuf, attrpath: String) -> Effect<Value, InfraError, NixqEnv> {
    Effect::new(move |env| {
        let value = read_value(env, &input)?;
        let path = parse_attrpath(&attrpath).map_err(|e| InfraError::Json(e.to_string()))?;
        get_at_path(&value, &path)
            .cloned()
            .ok_or_else(|| InfraError::Json(PathError::NotFound(path.display()).to_string()))
    })
}

pub fn cmd_has_attrs(
    input: PathBuf,
    attrs: Vec<String>,
) -> Effect<PredicateResult, InfraError, NixqEnv> {
    Effect::new(move |env| {
        let value = read_value(env, &input)?;
        Ok(PredicateResult::from_bool(value_has_attrs(&value, &attrs)))
    })
}

pub fn cmd_subset(
    input: PathBuf,
    expected: PathBuf,
) -> Effect<PredicateResult, InfraError, NixqEnv> {
    Effect::new(move |env| {
        let actual = read_value(env, &input)?;
        let expect = read_value(env, &expected)?;
        Ok(PredicateResult::from_bool(value_contains_subset(
            &actual, &expect,
        )))
    })
}

pub fn cmd_force_path(
    input: PathBuf,
    paths: Vec<String>,
) -> Effect<PredicateResult, InfraError, NixqEnv> {
    Effect::new(move |env| {
        let value = read_value(env, &input)?;
        Ok(PredicateResult::from_bool(
            force_paths(&value, &paths).is_ok(),
        ))
    })
}

pub fn cmd_normalize(input: PathBuf) -> Effect<Value, InfraError, NixqEnv> {
    Effect::new(move |env| {
        let value = read_value(env, &input)?;
        Ok(normalize_value(&value))
    })
}

pub fn cmd_diff(input: PathBuf, right: PathBuf) -> Effect<String, InfraError, NixqEnv> {
    Effect::new(move |env| {
        let left = read_value(env, &input)?;
        let right_v = read_value(env, &right)?;
        if values_equal(&left, &right_v) {
            return Ok(String::new());
        }
        Ok(structural_diff(
            &normalize_value(&left),
            &normalize_value(&right_v),
        ))
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::caps::{JsonSourceKey, MockJsonSource, mock_providers};
    use id_effect::{Cap, Exit, FromEnv, build_env, run_test};
    use std::sync::Arc;

    fn env_with(mock: Arc<MockJsonSource>) -> NixqEnv {
        let mut raw = build_env(mock_providers()).expect("env");
        raw.insert::<Cap<JsonSourceKey>>(mock as JsonSourceKey);
        NixqEnv::from_env(raw)
    }

    #[test]
    fn cmd_get_reads_attrpath() {
        let mock = Arc::new(MockJsonSource::default());
        mock.set_file("in.json", br#"{"a":{"b":2}}"#);
        let exit = run_test(
            cmd_get(PathBuf::from("in.json"), "a.b".into()),
            env_with(mock),
        );
        assert!(matches!(exit, Exit::Success(v) if v == serde_json::json!(2)));
    }

    #[test]
    fn cmd_has_attrs_predicate() {
        let mock = Arc::new(MockJsonSource::default());
        mock.set_file("in.json", br#"{"a":1,"b":2}"#);
        let exit = run_test(
            cmd_has_attrs(PathBuf::from("in.json"), vec!["a".into()]),
            env_with(mock),
        );
        assert!(matches!(exit, Exit::Success(PredicateResult::True)));
    }

    #[test]
    fn cmd_subset_false_when_missing() {
        let mock = Arc::new(MockJsonSource::default());
        mock.set_file("a.json", br#"{"a":1}"#);
        mock.set_file("e.json", br#"{"b":1}"#);
        let exit = run_test(
            cmd_subset(PathBuf::from("a.json"), PathBuf::from("e.json")),
            env_with(mock),
        );
        assert!(matches!(exit, Exit::Success(PredicateResult::False)));
    }

    #[test]
    fn cmd_force_path_and_normalize() {
        let mock = Arc::new(MockJsonSource::default());
        mock.set_file(
            "d.json",
            br#"{"outPath":"/nix/store/x","name":"x","builder":"b"}"#,
        );
        let exit = run_test(
            cmd_force_path(PathBuf::from("d.json"), vec!["outPath".into()]),
            env_with(mock.clone()),
        );
        assert!(matches!(exit, Exit::Success(PredicateResult::True)));

        let exit = run_test(cmd_normalize(PathBuf::from("d.json")), env_with(mock));
        match exit {
            Exit::Success(v) => {
                assert_eq!(v["type"], "derivation");
                assert_eq!(v["outPath"], "/nix/store/x");
            }
            other => panic!("unexpected {other:?}"),
        }
    }

    #[test]
    fn cmd_diff_equal_and_unequal() {
        let mock = Arc::new(MockJsonSource::default());
        mock.set_file("l.json", br#"{"a":1}"#);
        mock.set_file("r.json", br#"{"a":1}"#);
        let exit = run_test(
            cmd_diff(PathBuf::from("l.json"), PathBuf::from("r.json")),
            env_with(mock.clone()),
        );
        assert!(matches!(exit, Exit::Success(s) if s.is_empty()));

        mock.set_file("r2.json", br#"{"a":2}"#);
        let exit = run_test(
            cmd_diff(PathBuf::from("l.json"), PathBuf::from("r2.json")),
            env_with(mock),
        );
        assert!(matches!(exit, Exit::Success(s) if s.contains("~ $.a")));
    }

    #[test]
    fn load_json_and_error_paths() {
        let mock = Arc::new(MockJsonSource::default());
        mock.set_file("ok.json", br#"{"k":1}"#);
        mock.set_file("bad.json", b"not-json");
        assert!(matches!(
            run_test(load_json(PathBuf::from("ok.json")), env_with(mock.clone())),
            Exit::Success(_)
        ));
        assert!(matches!(
            run_test(load_json(PathBuf::from("bad.json")), env_with(mock.clone())),
            Exit::Failure(_)
        ));

        mock.set_file("obj.json", br#"{"a":1}"#);
        assert!(matches!(
            run_test(
                cmd_get(PathBuf::from("obj.json"), "missing".into()),
                env_with(mock.clone())
            ),
            Exit::Failure(_)
        ));
        assert!(matches!(
            run_test(
                cmd_get(PathBuf::from("obj.json"), ".".into()),
                env_with(mock.clone())
            ),
            Exit::Failure(_)
        ));
        assert!(matches!(
            run_test(
                cmd_has_attrs(PathBuf::from("obj.json"), vec!["z".into()]),
                env_with(mock.clone())
            ),
            Exit::Success(PredicateResult::False)
        ));
        assert!(matches!(
            run_test(
                cmd_force_path(PathBuf::from("obj.json"), vec!["a.b".into()]),
                env_with(mock.clone())
            ),
            Exit::Success(PredicateResult::False)
        ));
        mock.set_file("e.json", br#"{"a":1}"#);
        assert!(matches!(
            run_test(
                cmd_subset(PathBuf::from("obj.json"), PathBuf::from("e.json")),
                env_with(mock)
            ),
            Exit::Success(PredicateResult::True)
        ));
    }
}


/// Delegate path-info queries to nixstore (no SQL in nixq).
pub fn cmd_path_info(
    paths: Vec<String>,
    flags: nixstore::PathInfoFlags,
    store: Option<std::path::PathBuf>,
) -> Result<serde_json::Value, nixstore::InfraError> {
    use id_effect::{FromEnv, Exit, run_test};
    use nixstore::caps::{NixstoreEnv, providers_for_store};
    let root = nixstore::resolve_store_root(store);
    let env = NixstoreEnv::from_env(providers_for_store(&root));
    match run_test(nixstore::cmd_path_info(paths, flags), env) {
        Exit::Success(v) => Ok(v),
        Exit::Failure(cause) => Err(match cause {
            id_effect::Cause::Fail(e) => e,
            id_effect::Cause::Die(msg) => nixstore::InfraError::Json(msg),
            other => nixstore::InfraError::Json(format!("{other:?}")),
        }),
    }
}

#[cfg(test)]
mod path_info_tests {
    use super::*;
    use nixstore::PathInfoFlags;

    #[test]
    fn path_info_fixture_json() {
        let root = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../nixstore/fixtures/minimal");
        let path = "/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-a".to_string();
        let v = cmd_path_info(
            vec![path.clone()],
            PathInfoFlags {
                json: true,
                closure_size: true,
                referrers: true,
                ..Default::default()
            },
            Some(root),
        )
        .expect("query");
        assert_eq!(v[&path]["narSize"], 100);
        assert_eq!(v[&path]["closureSize"], 350);
    }
}
