//! Effect command programs for nixfetch.

use std::path::PathBuf;

use id_effect::{Effect, Needs};
use serde_json::Value;

use crate::caps::{GitFetchKey, HttpFetchKey, NixfetchEnv, PathIoKey};
use crate::error::InfraError;
use crate::hash_parse::{ExpectedHash, parse_expected_hash, verify_digest};
use crate::ingest::{hash_flat_bytes, hash_flat_path};
use crate::nar::hash_path_recursive;
use crate::verify::{digest_report, make_fixed_output_path};

pub fn cmd_hash(path: PathBuf, recursive: bool) -> Effect<Value, InfraError, NixfetchEnv> {
    Effect::new(move |_env| {
        let digest = if recursive {
            hash_path_recursive(&path)?
        } else {
            hash_flat_path(&path)?
        };
        Ok(Value::Object(digest_report(&digest)))
    })
}

pub fn cmd_verify(
    path: PathBuf,
    expected: String,
    recursive: bool,
) -> Effect<Value, InfraError, NixfetchEnv> {
    Effect::new(move |_env| {
        let want = parse_expected_hash(&expected)?;
        let digest = if recursive {
            hash_path_recursive(&path)?
        } else {
            hash_flat_path(&path)?
        };
        verify_digest(&want, &digest)?;
        let mut report = digest_report(&digest);
        report.insert("matched".into(), Value::Bool(true));
        Ok(Value::Object(report))
    })
}

pub fn cmd_fetch_url(
    url: String,
    expected: String,
    out: Option<PathBuf>,
    name: Option<String>,
) -> Effect<Value, InfraError, NixfetchEnv> {
    Effect::new(move |env| {
        let http = Needs::<HttpFetchKey>::need(env);
        let io = Needs::<PathIoKey>::need(env);
        let want = parse_expected_hash(&expected)?;
        let bytes = http.get(&url)?;
        let digest = hash_flat_bytes(&bytes);
        if let Some(ref path) = out {
            io.write_file(path, &bytes)?;
        }
        verify_digest(&want, &digest)?;
        let mut report = digest_report(&digest);
        report.insert("matched".into(), Value::Bool(true));
        report.insert("url".into(), Value::String(url.clone()));
        if let Some(ref path) = out {
            report.insert("out".into(), Value::String(path.display().to_string()));
        }
        if let Some(ref n) = name {
            let sp = make_fixed_output_path(n, false, &digest, None)?;
            report.insert(
                "storePath".into(),
                Value::String(sp.full_path(nixdrv::DEFAULT_STORE_DIR)),
            );
        }
        Ok(Value::Object(report))
    })
}

pub fn cmd_fetch_git(
    url: String,
    rev: String,
    expected: String,
    dest: Option<PathBuf>,
    name: Option<String>,
) -> Effect<Value, InfraError, NixfetchEnv> {
    Effect::new(move |env| {
        let git = Needs::<GitFetchKey>::need(env);
        let want = parse_expected_hash(&expected)?;
        let dest_path = dest.unwrap_or_else(|| {
            std::env::temp_dir().join(format!(
                "nixfetch-git-{}-{}",
                std::process::id(),
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .map(|d| d.as_nanos())
                    .unwrap_or(0)
            ))
        });
        let tree = git.export(&url, &rev, &dest_path)?;
        let digest = hash_path_recursive(&tree)?;
        verify_digest(&want, &digest)?;
        let mut report = digest_report(&digest);
        report.insert("matched".into(), Value::Bool(true));
        report.insert("url".into(), Value::String(url.clone()));
        report.insert("rev".into(), Value::String(rev.clone()));
        report.insert("out".into(), Value::String(tree.display().to_string()));
        if let Some(ref n) = name {
            let sp = make_fixed_output_path(n, true, &digest, None)?;
            report.insert(
                "storePath".into(),
                Value::String(sp.full_path(nixdrv::DEFAULT_STORE_DIR)),
            );
        }
        Ok(Value::Object(report))
    })
}

pub fn cmd_store_path(
    name: String,
    expected: String,
    recursive: bool,
    store_dir: Option<String>,
) -> Effect<Value, InfraError, NixfetchEnv> {
    Effect::new(move |_env| {
        let want = parse_expected_hash(&expected)?;
        let digest = match want {
            ExpectedHash::Digest(d) => d,
            ExpectedHash::Compressed(_) => {
                return Err(InfraError::Parse(
                    "store-path requires full digest (SRI or hex), not nix32 alone".into(),
                ));
            }
        };
        let sp = make_fixed_output_path(&name, recursive, &digest, store_dir.as_deref())?;
        let dir = store_dir.as_deref().unwrap_or(nixdrv::DEFAULT_STORE_DIR);
        Ok(serde_json::json!({
            "hash": sp.hash,
            "name": sp.name,
            "path": sp.full_path(dir),
            "digest": Value::Object(digest_report(&digest)),
        }))
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::caps::{MockGitFetch, MockHttpFetch, mock_env_with, mock_providers};
    use crate::hash_parse::{format_digest, format_nix32};
    use crate::ingest::hash_flat_bytes;
    use id_effect::{Exit, FromEnv, build_env, run_test};
    use std::sync::Arc;

    #[test]
    fn cmd_hash_flat_fixture() {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("fixtures/flat/hello");
        let env = NixfetchEnv::from_env(build_env(mock_providers()).expect("env"));
        let v = match run_test(cmd_hash(path, false), env) {
            Exit::Success(v) => v,
            other => panic!("hash failed: {other:?}"),
        };
        assert_eq!(
            v.get("hex").and_then(|x| x.as_str()).unwrap(),
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        );
    }

    #[test]
    fn cmd_verify_match_and_mismatch() {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("fixtures/flat/hello");
        let env = NixfetchEnv::from_env(build_env(mock_providers()).expect("env"));
        let dig = hash_flat_bytes(b"hello");
        let ok = run_test(
            cmd_verify(path.clone(), format_digest(&dig), false),
            env.clone(),
        );
        assert!(matches!(ok, Exit::Success(_)));

        let bad = run_test(cmd_verify(path, format_digest(&[0u8; 32]), false), env);
        assert!(matches!(bad, Exit::Failure(_)));
    }

    #[test]
    fn cmd_hash_recursive_golden() {
        let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("fixtures/nar/tree");
        let env = NixfetchEnv::from_env(build_env(mock_providers()).expect("env"));
        let v = match run_test(cmd_hash(path, true), env) {
            Exit::Success(v) => v,
            other => panic!("nar hash failed: {other:?}"),
        };
        assert_eq!(
            v.get("nix32").and_then(|x| x.as_str()).unwrap(),
            "0d0228wgvwp1443zlgfwd88kpzprzbsg5ifr6ikicg76ymwcy7lx"
        );
    }

    #[test]
    fn cmd_fetch_url_mock() {
        let http = Arc::new(MockHttpFetch::default());
        http.set("https://example.com/a", b"hello");
        let git = Arc::new(MockGitFetch::default());
        let env = mock_env_with(http, git);
        let dig = hash_flat_bytes(b"hello");
        let v = match run_test(
            cmd_fetch_url(
                "https://example.com/a".into(),
                format_digest(&dig),
                None,
                Some("pkg".into()),
            ),
            env,
        ) {
            Exit::Success(v) => v,
            other => panic!("fetch-url failed: {other:?}"),
        };
        assert_eq!(v.get("matched"), Some(&Value::Bool(true)));
        assert!(v.get("storePath").is_some());
    }

    #[test]
    fn cmd_fetch_git_mock() {
        let http = Arc::new(MockHttpFetch::default());
        let git = Arc::new(MockGitFetch::default());
        let tree = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("fixtures/nar/tree");
        git.set("https://git.example/repo.git", "deadbeef", &tree);
        let env = mock_env_with(http, git);
        let dig = hash_path_recursive(&tree).unwrap();
        let dest = std::env::temp_dir().join(format!("nixfetch-cmd-git-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dest);
        let v = match run_test(
            cmd_fetch_git(
                "https://git.example/repo.git".into(),
                "deadbeef".into(),
                format_nix32(&dig),
                Some(dest.clone()),
                Some("src".into()),
            ),
            env,
        ) {
            Exit::Success(v) => v,
            other => panic!("fetch-git failed: {other:?}"),
        };
        assert_eq!(v.get("matched"), Some(&Value::Bool(true)));
        let _ = std::fs::remove_dir_all(&dest);
    }

    #[test]
    fn cmd_store_path_rejects_compressed_nix32() {
        let env = NixfetchEnv::from_env(build_env(mock_providers()).expect("env"));
        let dig = hash_flat_bytes(b"hello");
        let compressed = nixdrv::nix_base32_encode(&nixdrv::compress_hash(&dig));
        let bad = run_test(
            cmd_store_path("n".into(), compressed, false, None),
            env.clone(),
        );
        assert!(matches!(bad, Exit::Failure(_)));
        let ok = run_test(
            cmd_store_path("n".into(), format_digest(&dig), false, None),
            env,
        );
        assert!(matches!(ok, Exit::Success(_)));
    }
}
