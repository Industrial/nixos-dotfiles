//! Effect programs for CLI commands.

use std::path::PathBuf;

use id_effect::{Effect, Needs};
use serde_json::{Map, Value, json};

use crate::caps::{NixstoreEnv, PathInfoStoreKey};
use crate::error::InfraError;
use crate::model::{QueryOpts, human_bytes};

#[derive(Debug, Clone, Default)]
pub struct PathInfoFlags {
    pub json: bool,
    pub size: bool,
    pub closure_size: bool,
    pub human_readable: bool,
    pub sigs: bool,
    pub referrers: bool,
}

/// Query one or more paths; JSON object keyed by path, or human lines.
pub fn cmd_path_info(
    paths: Vec<String>,
    flags: PathInfoFlags,
) -> Effect<Value, InfraError, NixstoreEnv> {
    Effect::new(move |env| {
        let store = Needs::<PathInfoStoreKey>::need(env);
        let opts = QueryOpts {
            include_referrers: flags.referrers,
            include_closure_size: flags.closure_size,
        };
        if flags.json {
            let mut out = Map::new();
            for p in &paths {
                let info = store.query(p, opts)?;
                out.insert(p.clone(), info.to_json_value());
            }
            return Ok(Value::Object(out));
        }

        // Non-JSON: emit text lines as a JSON string for the CLI to print.
        let mut lines = Vec::new();
        for p in &paths {
            let info = store.query(p, opts)?;
            let mut line = info.path.clone();
            if flags.size {
                let s = if flags.human_readable {
                    human_bytes(info.nar_size)
                } else {
                    info.nar_size.to_string()
                };
                line.push('\t');
                line.push_str(&s);
            }
            if flags.closure_size {
                let c = info.closure_size.unwrap_or(info.nar_size);
                let s = if flags.human_readable {
                    human_bytes(c)
                } else {
                    c.to_string()
                };
                line.push('\t');
                line.push_str(&s);
            }
            if flags.sigs && !info.signatures.is_empty() {
                line.push('\t');
                line.push_str(&info.signatures.join(" "));
            }
            lines.push(line);
            if flags.referrers
                && let Some(refs) = &info.referrers
            {
                for r in refs {
                    lines.push(format!("  referrer: {r}"));
                }
            }
        }
        Ok(json!({ "__text__": lines.join("\n") }))
    })
}

/// Convenience: resolve store root from an optional `--store`.
pub fn resolve_store_root(store: Option<PathBuf>) -> PathBuf {
    store.unwrap_or_else(|| PathBuf::from(crate::db::DEFAULT_STORE_ROOT))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::caps::{MockPathInfoStore, PathInfoStoreKey, mock_providers};
    use crate::model::PathInfo;
    use id_effect::{Cap, Exit, FromEnv, build_env, run_test};
    use std::sync::Arc;

    fn env_with(mock: Arc<MockPathInfoStore>) -> NixstoreEnv {
        let mut raw = build_env(mock_providers()).expect("env");
        raw.insert::<Cap<PathInfoStoreKey>>(mock as PathInfoStoreKey);
        NixstoreEnv::from_env(raw)
    }

    #[test]
    fn cmd_path_info_json() {
        let mock = Arc::new(MockPathInfoStore::default());
        mock.set(PathInfo {
            path: "/nix/store/x".into(),
            nar_hash: "sha256-AA".into(),
            nar_size: 12,
            deriver: None,
            registration_time: 1,
            ultimate: true,
            signatures: vec![],
            ca: None,
            references: vec![],
            referrers: None,
            closure_size: None,
        });
        let exit = run_test(
            cmd_path_info(
                vec!["/nix/store/x".into()],
                PathInfoFlags {
                    json: true,
                    ..Default::default()
                },
            ),
            env_with(mock),
        );
        match exit {
            Exit::Success(v) => {
                assert_eq!(v["/nix/store/x"]["narSize"], 12);
            }
            other => panic!("unexpected {other:?}"),
        }
    }
}
