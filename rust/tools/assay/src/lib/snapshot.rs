//! Golden snapshot store — read, write, and assert JSON fixtures on disk.

use std::path::{Path, PathBuf};

use serde_json::Value;

use crate::outcome::AssayOutcome;

/// Filesystem-backed store for named JSON snapshot goldens.
#[derive(Debug, Clone)]
pub struct SnapshotStore {
    pub root: PathBuf,
}

impl SnapshotStore {
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
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
    let diff = crate::diff::structural_diff(expected, observed);
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
}
