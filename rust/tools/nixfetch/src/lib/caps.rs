//! Capability keys and providers for nixfetch DI 3.0.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use id_effect::{Clock, Effect, Never, TestClock, caps, mock_capability, provide};

use crate::error::InfraError;

/// HTTP GET bytes for a URL.
pub trait HttpFetch: Send + Sync {
    fn get(&self, url: &str) -> Result<Vec<u8>, InfraError>;
}

#[derive(Debug, Default, Clone, Copy)]
pub struct LiveHttpFetch;

impl HttpFetch for LiveHttpFetch {
    fn get(&self, url: &str) -> Result<Vec<u8>, InfraError> {
        let response = reqwest::blocking::get(url).map_err(|e| InfraError::Http {
            url: url.into(),
            message: e.to_string(),
        })?;
        if !response.status().is_success() {
            return Err(InfraError::Http {
                url: url.into(),
                message: format!("status {}", response.status()),
            });
        }
        response.bytes().map(|b| b.to_vec()).map_err(|e| InfraError::Http {
            url: url.into(),
            message: e.to_string(),
        })
    }
}

#[derive(Default)]
pub struct MockHttpFetch {
    pub responses: Mutex<HashMap<String, Vec<u8>>>,
}

impl MockHttpFetch {
    pub fn set(&self, url: impl Into<String>, bytes: impl Into<Vec<u8>>) {
        self.responses.lock().unwrap().insert(url.into(), bytes.into());
    }
}

impl HttpFetch for MockHttpFetch {
    fn get(&self, url: &str) -> Result<Vec<u8>, InfraError> {
        self.responses
            .lock()
            .unwrap()
            .get(url)
            .cloned()
            .ok_or_else(|| InfraError::Http {
                url: url.into(),
                message: "mock: url not configured".into(),
            })
    }
}

/// Export a git tree at `rev` into `dest` (which should not exist yet or be empty).
pub trait GitFetch: Send + Sync {
    fn export(&self, url: &str, rev: &str, dest: &Path) -> Result<PathBuf, InfraError>;
}

#[derive(Debug, Default, Clone, Copy)]
pub struct LiveGitFetch;

impl GitFetch for LiveGitFetch {
    fn export(&self, url: &str, rev: &str, dest: &Path) -> Result<PathBuf, InfraError> {
        if dest.exists() {
            std::fs::remove_dir_all(dest).map_err(|e| InfraError::Io {
                path: dest.display().to_string(),
                message: e.to_string(),
            })?;
        }
        let status = Command::new("git")
            .args(["clone", "--depth", "1", url])
            .arg(dest)
            .status()
            .map_err(|e| InfraError::Git(e.to_string()))?;
        if !status.success() {
            // Retry without --depth for arbitrary revs.
            let _ = std::fs::remove_dir_all(dest);
            let status = Command::new("git")
                .args(["clone", url])
                .arg(dest)
                .status()
                .map_err(|e| InfraError::Git(e.to_string()))?;
            if !status.success() {
                return Err(InfraError::Git(format!("git clone failed for {url}")));
            }
        }
        let status = Command::new("git")
            .args(["-C"])
            .arg(dest)
            .args(["checkout", rev])
            .status()
            .map_err(|e| InfraError::Git(e.to_string()))?;
        if !status.success() {
            return Err(InfraError::Git(format!("git checkout {rev} failed")));
        }
        let git_dir = dest.join(".git");
        if git_dir.exists() {
            let _ = std::fs::remove_dir_all(&git_dir);
        }
        Ok(dest.to_path_buf())
    }
}

#[derive(Default)]
pub struct MockGitFetch {
    pub trees: Mutex<HashMap<(String, String), PathBuf>>,
}

impl MockGitFetch {
    pub fn set(&self, url: impl Into<String>, rev: impl Into<String>, tree: impl Into<PathBuf>) {
        self.trees
            .lock()
            .unwrap()
            .insert((url.into(), rev.into()), tree.into());
    }
}

impl GitFetch for MockGitFetch {
    fn export(&self, url: &str, rev: &str, dest: &Path) -> Result<PathBuf, InfraError> {
        let src = self
            .trees
            .lock()
            .unwrap()
            .get(&(url.to_string(), rev.to_string()))
            .cloned()
            .ok_or_else(|| InfraError::Git(format!("mock: no tree for {url}@{rev}")))?;
        copy_dir_all(&src, dest)?;
        Ok(dest.to_path_buf())
    }
}

pub(crate) fn copy_dir_all(src: &Path, dst: &Path) -> Result<(), InfraError> {
    std::fs::create_dir_all(dst).map_err(|e| InfraError::Io {
        path: dst.display().to_string(),
        message: e.to_string(),
    })?;
    for entry in std::fs::read_dir(src)
        .map_err(|e| InfraError::Io {
            path: src.display().to_string(),
            message: e.to_string(),
        })?
        .flatten()
    {
        let from = entry.path();
        let to = dst.join(entry.file_name());
        // Trusted trees only (mock git fixtures); skip unreadable entries.
        let Ok(ft) = entry.file_type() else {
            continue;
        };
        if ft.is_dir() {
            copy_dir_all(&from, &to)?;
        } else if ft.is_symlink() {
            let Ok(target) = std::fs::read_link(&from) else {
                continue;
            };
            std::os::unix::fs::symlink(&target, &to).map_err(|e| InfraError::Io {
                path: to.display().to_string(),
                message: e.to_string(),
            })?;
        } else {
            std::fs::copy(&from, &to).map_err(|e| InfraError::Io {
                path: to.display().to_string(),
                message: e.to_string(),
            })?;
        }
    }
    Ok(())
}

/// Filesystem read/write for download destinations.
pub trait PathIo: Send + Sync {
    fn write_file(&self, path: &Path, bytes: &[u8]) -> Result<(), InfraError>;
    fn read_file(&self, path: &Path) -> Result<Vec<u8>, InfraError>;
    fn create_dir_all(&self, path: &Path) -> Result<(), InfraError>;
}

#[derive(Debug, Default, Clone, Copy)]
pub struct FsPathIo;

impl PathIo for FsPathIo {
    fn write_file(&self, path: &Path, bytes: &[u8]) -> Result<(), InfraError> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).map_err(|e| InfraError::Io {
                path: parent.display().to_string(),
                message: e.to_string(),
            })?;
        }
        std::fs::write(path, bytes).map_err(|e| InfraError::Io {
            path: path.display().to_string(),
            message: e.to_string(),
        })
    }

    fn read_file(&self, path: &Path) -> Result<Vec<u8>, InfraError> {
        std::fs::read(path).map_err(|e| InfraError::Io {
            path: path.display().to_string(),
            message: e.to_string(),
        })
    }

    fn create_dir_all(&self, path: &Path) -> Result<(), InfraError> {
        std::fs::create_dir_all(path).map_err(|e| InfraError::Io {
            path: path.display().to_string(),
            message: e.to_string(),
        })
    }
}

#[derive(Default)]
pub struct MockPathIo {
    pub files: Mutex<HashMap<PathBuf, Vec<u8>>>,
}

impl PathIo for MockPathIo {
    fn write_file(&self, path: &Path, bytes: &[u8]) -> Result<(), InfraError> {
        self.files
            .lock()
            .unwrap()
            .insert(path.to_path_buf(), bytes.to_vec());
        Ok(())
    }

    fn read_file(&self, path: &Path) -> Result<Vec<u8>, InfraError> {
        self.files
            .lock()
            .unwrap()
            .get(path)
            .cloned()
            .ok_or_else(|| InfraError::Io {
                path: path.display().to_string(),
                message: "mock: file not found".into(),
            })
    }

    fn create_dir_all(&self, _path: &Path) -> Result<(), InfraError> {
        Ok(())
    }
}

pub type HttpFetchKey = Arc<dyn HttpFetch>;
pub type GitFetchKey = Arc<dyn GitFetch>;
pub type PathIoKey = Arc<dyn PathIo>;
pub type ClockKey = Arc<dyn Clock + Send + Sync>;

pub type NixfetchEnv = caps!(HttpFetchKey, GitFetchKey, PathIoKey, ClockKey);

#[derive(::id_effect::ProviderSpecDerive)]
#[provides(HttpFetchKey)]
pub struct LiveHttpFetchLive;

impl LiveHttpFetchLive {
    #[allow(clippy::new_ret_no_self)]
    fn new() -> HttpFetchKey {
        Arc::new(LiveHttpFetch)
    }
}

#[derive(::id_effect::ProviderSpecDerive)]
#[provides(GitFetchKey)]
pub struct LiveGitFetchLive;

impl LiveGitFetchLive {
    #[allow(clippy::new_ret_no_self)]
    fn new() -> GitFetchKey {
        Arc::new(LiveGitFetch)
    }
}

#[derive(::id_effect::ProviderSpecDerive)]
#[provides(PathIoKey)]
pub struct FsPathIoLive;

impl FsPathIoLive {
    #[allow(clippy::new_ret_no_self)]
    fn new() -> PathIoKey {
        Arc::new(FsPathIo)
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
    #[allow(clippy::new_ret_no_self)]
    fn new() -> ClockKey {
        Arc::new(StdClock)
    }
}

#[derive(::id_effect::ProviderSpecDerive)]
#[provides(ClockKey)]
pub struct NixfetchTestClockLive;

impl NixfetchTestClockLive {
    #[allow(clippy::new_ret_no_self)]
    fn new() -> ClockKey {
        Arc::new(TestClock::new(Instant::now()))
    }
}

mock_capability!(
    MockHttpFetchLive,
    HttpFetchKey,
    "http/mock",
    || Arc::new(MockHttpFetch::default()) as HttpFetchKey
);

mock_capability!(
    MockGitFetchLive,
    GitFetchKey,
    "git/mock",
    || Arc::new(MockGitFetch::default()) as GitFetchKey
);

mock_capability!(
    MockPathIoLive,
    PathIoKey,
    "pathio/mock",
    || Arc::new(MockPathIo::default()) as PathIoKey
);

pub fn live_providers() -> [id_effect::ProviderBox; 4] {
    [
        provide!(LiveHttpFetchLive),
        provide!(LiveGitFetchLive),
        provide!(FsPathIoLive),
        provide!(LiveClockLive),
    ]
}

/// Test/DI providers (mock HTTP/git/path + TestClock).
pub fn mock_providers() -> [id_effect::ProviderBox; 4] {
    [
        provide!(MockHttpFetchLive),
        provide!(MockGitFetchLive),
        provide!(MockPathIoLive),
        provide!(NixfetchTestClockLive),
    ]
}

/// Build a mock env with pre-configured HTTP/git arcs (tests).
pub fn mock_env_with(
    http: Arc<MockHttpFetch>,
    git: Arc<MockGitFetch>,
) -> NixfetchEnv {
    use id_effect::{Cap, Env, FromEnv, TestClock};
    let mut env = Env::new();
    env.insert::<Cap<HttpFetchKey>>(http as HttpFetchKey);
    env.insert::<Cap<GitFetchKey>>(git as GitFetchKey);
    env.insert::<Cap<PathIoKey>>(Arc::new(MockPathIo::default()) as PathIoKey);
    env.insert::<Cap<ClockKey>>(Arc::new(TestClock::new(Instant::now())) as ClockKey);
    NixfetchEnv::from_env(env)
}

#[cfg(test)]
mod tests {
    use super::*;
    use id_effect::{Cap, Effect, Exit, FromEnv, Needs, build_env, run_test};

    #[test]
    fn build_env_live_and_mock() {
        let live = build_env(live_providers()).expect("live");
        assert!(live.has::<Cap<HttpFetchKey>>());
        assert!(live.has::<Cap<GitFetchKey>>());
        assert!(live.has::<Cap<PathIoKey>>());
        assert!(live.has::<Cap<ClockKey>>());

        let mock = build_env(mock_providers()).expect("mock");
        assert!(mock.has::<Cap<HttpFetchKey>>());
    }

    #[test]
    fn mock_http_and_pathio() {
        let http = MockHttpFetch::default();
        http.set("https://x", b"body");
        assert_eq!(http.get("https://x").unwrap(), b"body");
        assert!(http.get("https://missing").is_err());

        let io = MockPathIo::default();
        io.write_file(Path::new("a"), b"1").unwrap();
        assert_eq!(io.read_file(Path::new("a")).unwrap(), b"1");
        assert!(io.read_file(Path::new("missing")).is_err());
    }

    #[test]
    fn run_test_needs_caps() {
        let env = NixfetchEnv::from_env(build_env(mock_providers()).expect("env"));
        let effect: Effect<bool, (), NixfetchEnv> = Effect::new(|env| {
            let _h = Needs::<HttpFetchKey>::need(env);
            let _g = Needs::<GitFetchKey>::need(env);
            let _p = Needs::<PathIoKey>::need(env);
            let _c = Needs::<ClockKey>::need(env);
            Ok(true)
        });
        assert_eq!(run_test(effect, env), Exit::Success(true));
    }

    #[test]
    fn mock_git_copies_tree() {
        let src = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("fixtures/git-tree");
        let dest = std::env::temp_dir().join(format!("nixfetch-git-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dest);
        let git = MockGitFetch::default();
        git.set("u", "r", &src);
        let out = git.export("u", "r", &dest).unwrap();
        assert!(out.join("file.txt").is_file());
        let _ = std::fs::remove_dir_all(&dest);
    }

    #[test]
    fn fs_path_io_roundtrip() {
        let dir = std::env::temp_dir().join(format!("nixfetch-pathio-{}", std::process::id()));
        let path = dir.join("f");
        let io = FsPathIo;
        io.write_file(&path, b"hi").unwrap();
        assert_eq!(io.read_file(&path).unwrap(), b"hi");
        io.create_dir_all(&dir.join("sub")).unwrap();
        let _ = std::fs::remove_dir_all(&dir);
    }
}
