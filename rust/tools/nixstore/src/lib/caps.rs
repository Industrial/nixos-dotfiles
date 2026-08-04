//! Capability keys and providers for nixstore DI 3.0.

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use id_effect::{Clock, Effect, Never, TestClock, Cap, caps, mock_capability, provide, build_env};
use rusqlite::Connection;

use crate::db::{open_store_db, query_path_info};
use crate::error::InfraError;
use crate::model::{PathInfo, QueryOpts};

/// Read path-info for store paths.
pub trait PathInfoStore: Send + Sync {
    fn query(&self, path: &str, opts: QueryOpts) -> Result<PathInfo, InfraError>;
}

/// Sqlite-backed store; opens DB under `store_root` on each query (RO URI).
#[derive(Debug, Clone)]
pub struct SqlitePathInfoStore {
    pub store_root: PathBuf,
}

impl SqlitePathInfoStore {
    pub fn new(store_root: impl Into<PathBuf>) -> Self {
        Self {
            store_root: store_root.into(),
        }
    }

    pub fn from_default() -> Self {
        Self::new(crate::db::DEFAULT_STORE_ROOT)
    }

    fn conn(&self) -> Result<Connection, InfraError> {
        open_store_db(&self.store_root)
    }
}

impl PathInfoStore for SqlitePathInfoStore {
    fn query(&self, path: &str, opts: QueryOpts) -> Result<PathInfo, InfraError> {
        let conn = self.conn()?;
        query_path_info(&conn, path, opts)
    }
}

/// In-memory path-info for tests.
#[derive(Default)]
pub struct MockPathInfoStore {
    pub paths: Mutex<HashMap<String, PathInfo>>,
}

impl MockPathInfoStore {
    pub fn set(&self, info: PathInfo) {
        self.paths.lock().unwrap().insert(info.path.clone(), info);
    }
}

impl PathInfoStore for MockPathInfoStore {
    fn query(&self, path: &str, opts: QueryOpts) -> Result<PathInfo, InfraError> {
        let mut info = self
            .paths
            .lock()
            .unwrap()
            .get(path)
            .cloned()
            .ok_or_else(|| InfraError::UnknownPath(path.into()))?;
        if !opts.include_referrers {
            info.referrers = None;
        }
        if !opts.include_closure_size {
            info.closure_size = None;
        }
        Ok(info)
    }
}

pub type PathInfoStoreKey = Arc<dyn PathInfoStore>;
pub type ClockKey = Arc<dyn Clock + Send + Sync>;

pub type NixstoreEnv = caps!(PathInfoStoreKey, ClockKey);

#[derive(::id_effect::ProviderSpecDerive)]
#[provides(PathInfoStoreKey)]
pub struct SqlitePathInfoStoreLive;

impl SqlitePathInfoStoreLive {
    #[allow(clippy::new_ret_no_self)] // ProviderSpecDerive factory returns capability key
    fn new() -> PathInfoStoreKey {
        Arc::new(SqlitePathInfoStore::from_default())
    }
}

#[derive(Debug, Default, Clone, Copy)]
pub struct StdClock;

impl Clock for StdClock {
    fn now(&self) -> Instant {
        Instant::now()
    }

    fn sleep(&self, duration: Duration) -> Effect<(), Never, ()> {
        Effect::new(move |_env| {
            std::thread::sleep(duration);
            Ok::<(), Never>(())
        })
    }

    fn sleep_until(&self, deadline: Instant) -> Effect<(), Never, ()> {
        let now = Instant::now();
        if deadline <= now {
            return Effect::new(|_| Ok::<(), Never>(()));
        }
        self.sleep(deadline.duration_since(now))
    }
}

#[derive(::id_effect::ProviderSpecDerive)]
#[provides(ClockKey)]
pub struct LiveClockLive;

impl LiveClockLive {
    #[allow(clippy::new_ret_no_self)] // ProviderSpecDerive factory returns capability key
    fn new() -> ClockKey {
        Arc::new(StdClock)
    }
}

#[derive(::id_effect::ProviderSpecDerive)]
#[provides(ClockKey)]
pub struct NixstoreTestClockLive;

impl NixstoreTestClockLive {
    #[allow(clippy::new_ret_no_self)] // ProviderSpecDerive factory returns capability key
    fn new() -> ClockKey {
        Arc::new(TestClock::new(Instant::now()))
    }
}

mock_capability!(
    MockPathInfoStoreLive,
    PathInfoStoreKey,
    "pathinfo/mock",
    || Arc::new(MockPathInfoStore::default()) as PathInfoStoreKey
);

pub fn live_providers() -> [id_effect::ProviderBox; 2] {
    [provide!(SqlitePathInfoStoreLive), provide!(LiveClockLive)]
}

/// Providers with a custom store root (CLI `--store`, fixtures).
pub fn providers_for_store(store_root: impl Into<PathBuf>) -> id_effect::Env {
    let mut env = build_env([provide!(LiveClockLive)]).expect("build clock");
    let store: PathInfoStoreKey = Arc::new(SqlitePathInfoStore::new(store_root));
    env.insert::<Cap<PathInfoStoreKey>>(store);
    env
}

#[cfg(test)]
pub fn mock_providers() -> [id_effect::ProviderBox; 2] {
    [provide!(MockPathInfoStoreLive), provide!(NixstoreTestClockLive)]
}

#[cfg(test)]
mod tests {
    use super::*;
    use id_effect::{Effect, Exit, FromEnv, Needs, run_test};

    #[test]
    fn mock_query() {
        let mock = MockPathInfoStore::default();
        mock.set(PathInfo {
            path: "/nix/store/x".into(),
            nar_hash: "sha256-x".into(),
            nar_size: 1,
            deriver: None,
            registration_time: 0,
            ultimate: false,
            signatures: vec![],
            ca: None,
            references: vec![],
            referrers: Some(vec!["/nix/store/y".into()]),
            closure_size: Some(1),
        });
        let info = mock
            .query("/nix/store/x", QueryOpts::default())
            .expect("q");
        assert!(info.referrers.is_none());
        assert!(info.closure_size.is_none());
    }

    #[test]
    fn build_env_materializes_mock_caps() {
        let env = build_env(mock_providers()).expect("env");
        assert!(env.has::<Cap<PathInfoStoreKey>>());
        assert!(env.has::<Cap<ClockKey>>());
    }

    #[test]
    fn run_test_reads_caps() {
        let env = NixstoreEnv::from_env(build_env(mock_providers()).expect("env"));
        let effect: Effect<bool, (), NixstoreEnv> = Effect::new(|env| {
            let _ = Needs::<PathInfoStoreKey>::need(env);
            Ok(true)
        });
        assert_eq!(run_test(effect, env), Exit::Success(true));
    }

    #[test]
    fn providers_for_store_inserts_cap() {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("fixtures/minimal");
        let env = providers_for_store(&root);
        assert!(env.has::<Cap<PathInfoStoreKey>>());
        assert!(env.has::<Cap<ClockKey>>());
    }
}
