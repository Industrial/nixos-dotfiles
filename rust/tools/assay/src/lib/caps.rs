//! Capability markers for dependency injection at the Assay runner edge.
//!
//! Evaluators, snapshot stores, fake stores, and clocks are injected — never globals.

use std::path::PathBuf;

use crate::outcome::AssayOutcome;

/// Marker for the real Nix evaluator capability (`NixEvaluator` in the runner graph).
#[derive(Debug, Clone, Copy, Default, Eq, PartialEq)]
pub struct NixEvaluator;

/// Golden-file store rooted at `root` (typically `testdata/goldens/`).
#[derive(Debug, Clone, Eq, PartialEq)]
pub struct SnapshotStore {
    pub root: PathBuf,
}

/// Marker for an in-memory / fake nix store used in unit tests.
///
/// IFD (import-from-derivation) requires a `FakeStore` with [`FakeStore::allow_ifd`] true;
/// the default denies IFD until sandbox wiring is implemented.
#[derive(Debug, Clone, Copy, Default, Eq, PartialEq)]
pub struct FakeStore;

impl FakeStore {
    /// Whether this fake store permits import-from-derivation during module evaluation.
    ///
    /// The default `FakeStore` always returns `false`. Future sandboxed module tests must
    /// construct a `FakeStore` with IFD enabled (not yet implemented).
    pub fn allow_ifd(&self) -> bool {
        false
    }
}

/// Injectable clock for deterministic time-dependent claims.
#[derive(Debug, Clone, Copy, Eq, PartialEq)]
pub struct TestClock {
    pub millis: u64,
}

/// Injected capabilities for an Assay run or unit-test harness.
#[derive(Debug, Clone, Eq, PartialEq)]
pub struct Caps {
    pub evaluator: NixEvaluator,
    pub snapshots: SnapshotStore,
    pub store: Option<FakeStore>,
    pub clock: TestClock,
}

impl Caps {
    /// Build a minimal capability set for unit tests (no fake store, clock at 0).
    pub fn unit_test(goldens: impl Into<PathBuf>) -> Self {
        Self {
            evaluator: NixEvaluator,
            snapshots: SnapshotStore::new(goldens),
            store: None,
            clock: TestClock::new(0),
        }
    }
}

/// Require a [`FakeStore`] for sandboxed / IFD module evaluation.
pub fn require_store(caps: &Caps) -> Result<&FakeStore, AssayOutcome> {
    caps.store.as_ref().ok_or(AssayOutcome::EvalError {
        kind: "sandbox".into(),
        message: "IFD denied: provide FakeStore capability".into(),
        span: None,
    })
}

impl SnapshotStore {
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
    }

    /// Path to the golden JSON for `name` (`<root>/<name>.json`).
    pub fn path_for(&self, name: &str) -> PathBuf {
        self.root.join(format!("{name}.json"))
    }
}

impl TestClock {
    pub fn new(millis: u64) -> Self {
        Self { millis }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn snapshot_store_path_for_appends_json_extension() {
        let store = SnapshotStore::new("/tmp/goldens");
        assert_eq!(
            store.path_for("my_case"),
            PathBuf::from("/tmp/goldens/my_case.json")
        );
    }

    #[test]
    fn snapshot_store_path_for_nested_name() {
        let store = SnapshotStore::new("testdata/goldens");
        assert_eq!(
            store.path_for("suite/case"),
            PathBuf::from("testdata/goldens/suite/case.json")
        );
    }

    #[test]
    fn fake_store_denies_ifd_by_default() {
        assert!(!FakeStore::default().allow_ifd());
    }

    #[test]
    fn unit_test_caps_has_no_store_and_zero_clock() {
        let caps = Caps::unit_test("/tmp/goldens");
        assert!(caps.store.is_none());
        assert_eq!(caps.clock.millis, 0);
        assert_eq!(
            caps.snapshots.path_for("case"),
            PathBuf::from("/tmp/goldens/case.json")
        );
    }

    #[test]
    fn require_store_err_when_missing() {
        let caps = Caps::unit_test("/tmp/goldens");
        assert_eq!(
            require_store(&caps),
            Err(AssayOutcome::EvalError {
                kind: "sandbox".into(),
                message: "IFD denied: provide FakeStore capability".into(),
                span: None,
            })
        );
    }

    #[test]
    fn require_store_ok_when_present() {
        let caps = Caps {
            evaluator: NixEvaluator,
            snapshots: SnapshotStore::new("/tmp/goldens"),
            store: Some(FakeStore),
            clock: TestClock::new(0),
        };
        assert!(require_store(&caps).is_ok());
    }
}
