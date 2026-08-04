//! Golden snapshot store — read, write, and assert JSON fixtures on disk.

use std::path::{Path, PathBuf};

use serde_json::Value;

use crate::outcome::AssayOutcome;

/// Filesystem-backed store for named JSON snapshot goldens.
#[derive(Debug, Clone)]
pub struct SnapshotStore {
    pub root: PathBuf,
    pub update_snapshots: bool,
}

impl SnapshotStore {
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self {
            root: root.into(),
            update_snapshots: false,
        }
    }

    /// Return a copy with [`SnapshotStore::update_snapshots`] set (for `--update-snapshots`).
    pub fn with_update(mut self, update: bool) -> Self {
        self.update_snapshots = update;
        self
    }

    pub fn read(&self, name: &str) -> anyhow::Result<Option<Value>> {
        let path = self.golden_path(name);
        if !path.exists() {
            return Ok(None);
        }
        let text = std::fs::read_to_string(path)?;
        Ok(Some(serde_json::from_str(&text)?))
    }

    pub fn write(&self, name: &str, value: &Value) -> anyhow::Result<()> {
        let path = self.golden_path(name);
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let text = serde_json::to_string_pretty(value)?;
        std::fs::write(path, format!("{text}\n"))?;
        Ok(())
    }

    pub fn assert_match(&self, name: &str, observed: &Value, update: bool) -> AssayOutcome {
        let update = update || self.update_snapshots;
        let path = self.golden_path(name);
        if update {
            return match self.write(name, observed) {
                Ok(()) => AssayOutcome::Pass,
                Err(err) => io_error(err),
            };
        }

        let expected = match self.read(name) {
            Ok(Some(value)) => value,
            Ok(None) => {
                return AssayOutcome::SnapshotMismatch {
                    path: display_path(&path),
                    diff: "golden missing".into(),
                };
            }
            Err(err) => return io_error(err),
        };

        if &expected == observed {
            AssayOutcome::Pass
        } else {
            AssayOutcome::SnapshotMismatch {
                path: display_path(&path),
                diff: snapshot_diff(&expected, observed),
            }
        }
    }

    fn golden_path(&self, name: &str) -> PathBuf {
        self.root.join(format!("{name}.json"))
    }
}

fn snapshot_diff(expected: &Value, observed: &Value) -> String {
    let diff = nixq::structural_diff(expected, observed);
    if diff.is_empty() {
        format!("expected: {expected:?}\nobserved: {observed:?}")
    } else {
        diff
    }
}

fn display_path(path: &Path) -> String {
    path.display().to_string()
}

fn io_error(err: anyhow::Error) -> AssayOutcome {
    AssayOutcome::EvalError {
        kind: "io".into(),
        message: err.to_string(),
        span: None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    struct TempStore {
        _dir: std::path::PathBuf,
        store: SnapshotStore,
    }

    impl TempStore {
        fn new() -> Self {
            let dir = std::env::temp_dir().join(format!(
                "assay-snapshot-{}-{}",
                std::process::id(),
                std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_nanos()
            ));
            std::fs::create_dir_all(&dir).expect("tempdir");
            Self {
                store: SnapshotStore::new(&dir),
                _dir: dir,
            }
        }
    }

    impl Drop for TempStore {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self._dir);
        }
    }

    #[test]
    fn read_missing_returns_none() {
        let temp = TempStore::new();
        let store = &temp.store;
        assert!(store.read("missing").unwrap().is_none());
    }

    #[test]
    fn write_then_read_round_trips() {
        let temp = TempStore::new();
        let store = &temp.store;
        let value = json!({"a": 1, "b": [2, 3]});
        store.write("roundtrip", &value).unwrap();
        assert_eq!(store.read("roundtrip").unwrap(), Some(value));
    }

    #[test]
    fn write_nested_golden_creates_parent_dirs() {
        let temp = TempStore::new();
        let store = &temp.store;
        let value = json!({"nested": true});
        store.write("nested/deep/golden", &value).unwrap();
        assert_eq!(store.read("nested/deep/golden").unwrap(), Some(value));
    }

    #[test]
    fn assert_match_passes_when_equal() {
        let temp = TempStore::new();
        let store = &temp.store;
        let value = json!({"x": 1});
        store.write("eq", &value).unwrap();
        assert_eq!(store.assert_match("eq", &value, false), AssayOutcome::Pass);
    }

    #[test]
    fn assert_match_missing_is_snapshot_mismatch() {
        let temp = TempStore::new();
        let store = &temp.store;
        let out = store.assert_match("absent", &json!(1), false);
        assert!(matches!(out, AssayOutcome::SnapshotMismatch { .. }));
    }

    #[test]
    fn assert_match_differs_reports_structural_diff() {
        let temp = TempStore::new();
        let store = &temp.store;
        store.write("diff", &json!({"a": 1})).unwrap();
        let out = store.assert_match("diff", &json!({"a": 2}), false);
        match out {
            AssayOutcome::SnapshotMismatch { diff, .. } => assert!(diff.contains("$.a")),
            other => panic!("expected SnapshotMismatch, got {other:?}"),
        }
    }

    #[test]
    fn assert_match_update_writes_and_passes() {
        let temp = TempStore::new();
        let store = &temp.store;
        let value = json!({"fresh": true});
        assert_eq!(store.assert_match("new", &value, true), AssayOutcome::Pass);
        assert_eq!(store.read("new").unwrap(), Some(value));
    }

    #[test]
    fn snapshot_diff_uses_debug_when_values_equal() {
        let v = json!({"k": 1});
        let diff = snapshot_diff(&v, &v);
        assert!(diff.contains("expected:"));
        assert!(diff.contains("observed:"));
    }

    #[test]
    fn assert_match_corrupt_golden_returns_io_error() {
        let temp = TempStore::new();
        let store = &temp.store;
        store.write("corrupt", &json!(1)).unwrap();
        let path = temp.store.root.join("corrupt.json");
        std::fs::write(&path, "not-json").unwrap();
        match store.assert_match("corrupt", &json!(2), false) {
            AssayOutcome::EvalError { kind, .. } => assert_eq!(kind, "io"),
            other => panic!("expected io error, got {other:?}"),
        }
    }

    #[test]
    fn write_without_parent_directory() {
        let name = format!("assay_snap_bare_{}", std::process::id());
        let store = SnapshotStore::new("");
        let path = PathBuf::from(format!("{name}.json"));
        let _ = std::fs::remove_file(&path);
        store.write(&name, &json!(1)).unwrap();
        assert!(path.exists());
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn with_update_flag_drives_assert_match() {
        let temp = TempStore::new();
        let store = temp.store.clone().with_update(true);
        let value = json!({"flag": true});
        assert_eq!(
            store.assert_match("flagged", &value, false),
            AssayOutcome::Pass
        );
        assert_eq!(store.read("flagged").unwrap(), Some(value));
    }
}

#[cfg(test)]
mod golden_contract {
    use id_effect::testing::snapshot::{GoldenBuilder, SnapshotAssertion, assert_golden_effect};
    use id_effect::{Effect, succeed};

    #[test]
    fn golden_builder_assert_observed_passes_on_match() {
        GoldenBuilder::new("assay_store_roundtrip", r#"{"ok":true}"#)
            .assert_observed(r#"{"ok":true}"#);
    }

    fn snapshot_store_contract_effect() -> Effect<SnapshotAssertion, (), ()> {
        succeed(SnapshotAssertion {
            name: "assay_snapshot_store_contract",
            observed: r#"{"via":"store"}"#.into(),
            expected: r#"{"via":"store"}"#,
        })
    }

    #[test]
    fn assert_golden_effect_runs_store_contract() {
        let snap = assert_golden_effect(snapshot_store_contract_effect(), ());
        assert_eq!(snap.name, "assay_snapshot_store_contract");
        assert!(snap.matches());
    }
}
