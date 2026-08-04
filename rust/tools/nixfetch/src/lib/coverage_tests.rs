//! Coverage exercises for live caps, NAR edge cases, and command branches.

use std::io::{Read, Write};
use std::net::TcpListener;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

use id_effect::{Clock, Exit, FromEnv, build_env, run_test};
use serde_json::Value;

use crate::caps::{
    FsPathIo, GitFetch, HttpFetch, LiveGitFetch, LiveHttpFetch, MockGitFetch, MockHttpFetch,
    MockPathIo, NixfetchEnv, PathIo, StdClock, copy_dir_all, live_providers, mock_env_with,
    mock_providers,
};
use crate::commands::{cmd_fetch_git, cmd_fetch_url, cmd_hash, cmd_store_path, cmd_verify};
use crate::error::InfraError;
use crate::hash_parse::{
    ExpectedHash, format_digest, format_nix32, nix32_decode_digest, nix32_encode_bytes,
    parse_expected_hash, verify_digest,
};
use crate::ingest::hash_flat_bytes;
use crate::nar::{hash_path_recursive, nar_bytes, nar_serialize};
use crate::verify::{digest_report, make_fixed_output_path, verify_or_err};

fn tmp_dir(tag: &str) -> PathBuf {
    std::env::temp_dir().join(format!(
        "nixfetch-cov-{tag}-{}-{}",
        std::process::id(),
        Instant::now().elapsed().as_nanos()
    ))
}

fn serve_http_once(status_line: &str, body: &[u8]) -> String {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    let status = status_line.to_string();
    let body = body.to_vec();
    thread::spawn(move || {
        let (mut stream, _) = listener.accept().unwrap();
        let mut buf = [0u8; 1024];
        let _ = stream.read(&mut buf);
        let resp = format!(
            "{status}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
            body.len()
        );
        let _ = stream.write_all(resp.as_bytes());
        let _ = stream.write_all(&body);
    });
    format!("http://{addr}/blob")
}

#[test]
fn std_clock_now_sleep_and_deadlines() {
    let clock = StdClock;
    let _ = clock.now();
    assert!(matches!(run_test(clock.sleep(Duration::from_millis(1)), ()), Exit::Success(())));
    let past = Instant::now() - Duration::from_secs(1);
    assert!(matches!(run_test(clock.sleep_until(past), ()), Exit::Success(())));
    let future = Instant::now() + Duration::from_millis(1);
    assert!(matches!(run_test(clock.sleep_until(future), ()), Exit::Success(())));
}

#[test]
fn live_http_fetch_ok_and_status_error() {
    let http = LiveHttpFetch;
    assert_eq!(http.get(&serve_http_once("HTTP/1.1 200 OK", b"hello-cov")).unwrap(), b"hello-cov");
    assert!(matches!(http.get(&serve_http_once("HTTP/1.1 404 Not Found", b"nope")).unwrap_err(), InfraError::Http { .. }));
}

#[test]
fn live_http_fetch_connection_error() {
    assert!(matches!(LiveHttpFetch.get("http://127.0.0.1:1/definitely-closed").unwrap_err(), InfraError::Http { .. }));
}

#[test]
fn live_git_fetch_local_repo() {
    let repo = tmp_dir("git-src");
    let dest = tmp_dir("git-dest");
    let _ = std::fs::remove_dir_all(&repo);
    let _ = std::fs::remove_dir_all(&dest);
    std::fs::create_dir_all(&repo).unwrap();
    for args in [
        vec!["init"],
        vec!["config", "user.email", "cov@example.com"],
        vec!["config", "user.name", "cov"],
    ] {
        assert!(Command::new("git").args(&args).current_dir(&repo).status().unwrap().success());
    }
    std::fs::write(repo.join("tracked.txt"), b"git-cov").unwrap();
    assert!(Command::new("git").args(["add", "tracked.txt"]).current_dir(&repo).status().unwrap().success());
    assert!(Command::new("git").args(["commit", "-m", "c"]).current_dir(&repo).status().unwrap().success());
    let rev = String::from_utf8(
        Command::new("git").args(["rev-parse", "HEAD"]).current_dir(&repo).output().unwrap().stdout,
    )
    .unwrap()
    .trim()
    .to_string();
    std::fs::create_dir_all(&dest).unwrap();
    let url = format!("file://{}", repo.display());
    let out = LiveGitFetch.export(&url, &rev, &dest).unwrap();
    assert!(out.join("tracked.txt").is_file());
    assert!(!out.join(".git").exists());
    assert!(LiveGitFetch
        .export(&url, "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef", &tmp_dir("git-bad"))
        .is_err());
    let _ = std::fs::remove_dir_all(&repo);
    let _ = std::fs::remove_dir_all(&dest);
}

#[test]
fn live_git_fetch_clone_failure() {
    let dest = tmp_dir("git-fail");
    let _ = std::fs::remove_dir_all(&dest);
    assert!(matches!(
        LiveGitFetch
            .export("file:///nonexistent/nixfetch-no-repo", "HEAD", &dest)
            .unwrap_err(),
        InfraError::Git(_)
    ));
}

#[test]
fn mock_git_copies_symlink_tree() {
    let src = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("fixtures/nar/tree");
    let dest = tmp_dir("mock-symlink");
    let _ = std::fs::remove_dir_all(&dest);
    let git = MockGitFetch::default();
    git.set("u", "r", &src);
    let out = git.export("u", "r", &dest).unwrap();
    assert!(out.join("link").symlink_metadata().unwrap().file_type().is_symlink());
    let _ = std::fs::remove_dir_all(&dest);
}

#[test]
fn fs_path_io_error_paths() {
    let io = FsPathIo;
    assert!(matches!(
        io.read_file(Path::new("/nonexistent/nixfetch-cov/nope.bin"))
            .unwrap_err(),
        InfraError::Io { .. }
    ));
    let blocker = tmp_dir("pathio-blocker");
    let _ = std::fs::remove_dir_all(&blocker);
    std::fs::create_dir_all(blocker.parent().unwrap()).unwrap();
    std::fs::write(&blocker, b"file").unwrap();
    assert!(io.write_file(&blocker.join("child"), b"x").is_err());
    let _ = std::fs::remove_file(&blocker);
}

#[test]
fn live_providers_env_has_caps() {
    let _env = NixfetchEnv::from_env(build_env(live_providers()).expect("live"));
}

#[test]
fn nar_missing_path_and_executable() {
    let missing = Path::new("/nonexistent/nixfetch-nar-missing");
    assert!(nar_serialize(missing, &mut Vec::new()).is_err());
    assert!(hash_path_recursive(missing).is_err());
    assert!(nar_bytes(missing).is_err());
    let dir = tmp_dir("nar-exec");
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join("tool");
    std::fs::write(&path, b"#!/bin/sh\necho hi\n").unwrap();
    let mut perms = std::fs::metadata(&path).unwrap().permissions();
    perms.set_mode(0o755);
    std::fs::set_permissions(&path, perms).unwrap();
    let dig = hash_path_recursive(&path).unwrap();
    assert_ne!(
        hex::encode(dig),
        hex::encode(hash_flat_bytes(b"#!/bin/sh\necho hi\n"))
    );
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn nar_empty_directory() {
    let dir = tmp_dir("nar-empty-dir");
    std::fs::create_dir_all(&dir).unwrap();
    assert!(!nar_bytes(&dir).unwrap().is_empty());
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn hash_parse_edge_cases() {
    assert!(nix32_decode_digest("abc").is_err());
    let mut bad = "0".repeat(52);
    bad.replace_range(0..1, "!");
    assert!(nix32_decode_digest(&bad).is_err());
    assert!(!nix32_encode_bytes(&[1, 2, 3]).is_empty());
    let d = hash_flat_bytes(b"hello");
    let compressed = nixdrv::compress_hash(&d);
    let enc = nixdrv::nix_base32_encode(&compressed);
    assert!(matches!(
        parse_expected_hash(&enc).unwrap(),
        ExpectedHash::Compressed(_)
    ));
    assert!(matches!(
        verify_digest(&ExpectedHash::Compressed(compressed), &[9u8; 32]),
        Err(InfraError::HashMismatch { .. })
    ));
    assert!(parse_expected_hash("sha256-YWJj").is_err());
}

#[test]
fn verify_helpers_and_report() {
    let d = hash_flat_bytes(b"hi");
    let sp = make_fixed_output_path("n", true, &d, Some("/tmp/store")).unwrap();
    assert_eq!(sp.name, "n");
    let report = digest_report(&d);
    assert!(report.get("sri").is_some() || report.get("hex").is_some());
    verify_or_err(&ExpectedHash::Digest(d), &d).unwrap();
    assert!(verify_or_err(&ExpectedHash::Digest(d), &[0u8; 32]).is_err());
}

#[test]
fn cmd_verify_recursive_and_hash_errors() {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("fixtures/nar/tree");
    let env = NixfetchEnv::from_env(build_env(mock_providers()).expect("env"));
    let dig = hash_path_recursive(&path).unwrap();
    assert!(matches!(
        run_test(cmd_verify(path.clone(), format_nix32(&dig), true), env.clone()),
        Exit::Success(_)
    ));
    assert!(matches!(
        run_test(cmd_hash(PathBuf::from("/no/such"), false), env.clone()),
        Exit::Failure(_)
    ));
    assert!(matches!(
        run_test(cmd_verify(path, "not-a-hash".into(), true), env),
        Exit::Failure(_)
    ));
}

#[test]
fn cmd_fetch_url_writes_out_and_mismatch() {
    let http = Arc::new(MockHttpFetch::default());
    http.set("https://example.com/b", b"body");
    let git = Arc::new(MockGitFetch::default());
    let env = mock_env_with(http, git);
    let dig = hash_flat_bytes(b"body");
    let out = tmp_dir("fetch-out").join("blob");
    let v = match run_test(
        cmd_fetch_url(
            "https://example.com/b".into(),
            format_digest(&dig),
            Some(out),
            None,
        ),
        env.clone(),
    ) {
        Exit::Success(v) => v,
        other => panic!("fetch-url write failed: {other:?}"),
    };
    assert_eq!(v.get("matched"), Some(&Value::Bool(true)));
    assert!(v.get("out").is_some());
    assert!(matches!(
        run_test(
            cmd_fetch_url(
                "https://example.com/b".into(),
                format_digest(&[0u8; 32]),
                None,
                None,
            ),
            env,
        ),
        Exit::Failure(_)
    ));
}

#[test]
fn cmd_fetch_git_default_dest_and_mismatch() {
    let http = Arc::new(MockHttpFetch::default());
    let git = Arc::new(MockGitFetch::default());
    let tree = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("fixtures/nar/tree");
    git.set("https://git.example/r.git", "abc", &tree);
    let env = mock_env_with(http, git);
    let dig = hash_path_recursive(&tree).unwrap();
    let v = match run_test(
        cmd_fetch_git(
            "https://git.example/r.git".into(),
            "abc".into(),
            format_nix32(&dig),
            None,
            None,
        ),
        env.clone(),
    ) {
        Exit::Success(v) => v,
        other => panic!("fetch-git default dest failed: {other:?}"),
    };
    assert_eq!(v.get("matched"), Some(&Value::Bool(true)));
    if let Some(out) = v.get("out").and_then(|x| x.as_str()) {
        let _ = std::fs::remove_dir_all(out);
    }
    assert!(matches!(
        run_test(
            cmd_fetch_git(
                "https://git.example/r.git".into(),
                "abc".into(),
                format_digest(&[0u8; 32]),
                Some(tmp_dir("git-mm")),
                Some("n".into()),
            ),
            env,
        ),
        Exit::Failure(_)
    ));
}

#[test]
fn live_git_dest_is_file_remove_fails() {
    let dest = tmp_dir("git-file-dest");
    let _ = std::fs::remove_dir_all(&dest);
    if let Some(parent) = dest.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    std::fs::write(&dest, b"not-a-dir").unwrap();
    assert!(matches!(
        LiveGitFetch
            .export("file:///nonexistent/repo", "HEAD", &dest)
            .unwrap_err(),
        InfraError::Io { .. } | InfraError::Git(_)
    ));
    let _ = std::fs::remove_file(&dest);
}

#[test]
fn mock_git_export_src_file_errors() {
    let src = tmp_dir("git-src-file");
    let dest = tmp_dir("git-dest-bad");
    let _ = std::fs::remove_dir_all(&dest);
    if let Some(parent) = src.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    std::fs::write(&src, b"not-tree").unwrap();
    let git = MockGitFetch::default();
    git.set("u", "r", &src);
    assert!(matches!(git.export("u", "r", &dest).unwrap_err(), InfraError::Io { .. }));
    let _ = std::fs::remove_file(&src);
}

#[test]
fn mock_path_io_create_dir_all_ok() {
    let io = MockPathIo::default();
    io.create_dir_all(Path::new("/any/path")).unwrap();
}

#[test]
fn fs_path_io_create_dir_all_error() {
    let blocker = tmp_dir("mkdir-blocker");
    let _ = std::fs::remove_dir_all(&blocker);
    std::fs::create_dir_all(blocker.parent().unwrap()).unwrap();
    std::fs::write(&blocker, b"file").unwrap();
    assert!(FsPathIo.create_dir_all(&blocker.join("child")).is_err());
    let _ = std::fs::remove_file(&blocker);
}

#[test]
fn live_http_truncated_body_errors() {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    thread::spawn(move || {
        let (mut stream, _) = listener.accept().unwrap();
        let mut buf = [0u8; 1024];
        let _ = stream.read(&mut buf);
        let _ = stream.write_all(b"HTTP/1.1 200 OK\r\nContent-Length: 100\r\nConnection: close\r\n\r\nshort");
        // close early → body shorter than Content-Length
    });
    let url = format!("http://{addr}/trunc");
    assert!(matches!(LiveHttpFetch.get(&url).unwrap_err(), InfraError::Http { .. }));
}

#[test]
fn nar_unreadable_file_and_dir() {
    let dir = tmp_dir("nar-perm");
    std::fs::create_dir_all(&dir).unwrap();
    let file = dir.join("secret");
    std::fs::write(&file, b"x").unwrap();
    let mut perms = std::fs::metadata(&file).unwrap().permissions();
    perms.set_mode(0o000);
    std::fs::set_permissions(&file, perms).unwrap();
    assert!(hash_path_recursive(&file).is_err());
    let mut dperms = std::fs::metadata(&dir).unwrap().permissions();
    dperms.set_mode(0o000);
    std::fs::set_permissions(&dir, dperms).unwrap();
    assert!(hash_path_recursive(&dir).is_err());
    let mut restore = std::fs::metadata(&dir).unwrap().permissions();
    restore.set_mode(0o755);
    std::fs::set_permissions(&dir, restore).unwrap();
    let mut frestore = std::fs::metadata(&file).unwrap().permissions();
    frestore.set_mode(0o644);
    std::fs::set_permissions(&file, frestore).unwrap();
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn cmd_fetch_git_with_name_ok() {
    let http = Arc::new(MockHttpFetch::default());
    let git = Arc::new(MockGitFetch::default());
    let tree = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("fixtures/nar/tree");
    git.set("https://git.example/named.git", "rev", &tree);
    let env = mock_env_with(http, git);
    let dig = hash_path_recursive(&tree).unwrap();
    let dest = tmp_dir("git-named");
    let _ = std::fs::remove_dir_all(&dest);
    let v = match run_test(
        cmd_fetch_git(
            "https://git.example/named.git".into(),
            "rev".into(),
            format_nix32(&dig),
            Some(dest.clone()),
            Some("src".into()),
        ),
        env,
    ) {
        Exit::Success(v) => v,
        other => panic!("named fetch-git failed: {other:?}"),
    };
    assert!(v.get("storePath").is_some());
    let _ = std::fs::remove_dir_all(&dest);
}

#[test]
fn cmd_fetch_url_missing_mock_url() {
    let http = Arc::new(MockHttpFetch::default());
    let git = Arc::new(MockGitFetch::default());
    let env = mock_env_with(http, git);
    assert!(matches!(
        run_test(
            cmd_fetch_url(
                "https://missing".into(),
                format_digest(&[0u8; 32]),
                None,
                None,
            ),
            env,
        ),
        Exit::Failure(_)
    ));
}

#[test]
fn cmd_store_path_recursive_and_custom_store() {
    let env = NixfetchEnv::from_env(build_env(mock_providers()).expect("env"));
    let dig = hash_flat_bytes(b"hello");
    let v = match run_test(
        cmd_store_path(
            "pkg".into(),
            format_digest(&dig),
            true,
            Some("/custom/store".into()),
        ),
        env,
    ) {
        Exit::Success(v) => v,
        other => panic!("store-path failed: {other:?}"),
    };
    assert!(
        v.get("path")
            .and_then(|p| p.as_str())
            .unwrap()
            .starts_with("/custom/store/")
    );
}

#[test]
fn copy_dir_all_error_paths() {
    let root = tmp_dir("copy-err");
    let _ = std::fs::remove_dir_all(&root);
    std::fs::create_dir_all(&root).unwrap();

    // Destination parent is a file → create_dir_all fails.
    let blocker = root.join("blocker");
    std::fs::write(&blocker, b"x").unwrap();
    let src_ok = root.join("src-ok");
    std::fs::create_dir_all(&src_ok).unwrap();
    std::fs::write(src_ok.join("f"), b"1").unwrap();
    assert!(matches!(
        copy_dir_all(&src_ok, &blocker.join("child")).unwrap_err(),
        InfraError::Io { .. }
    ));

    // Symlink collide: destination already has a regular file with the link name.
    let src_link = root.join("src-link");
    let dst_link = root.join("dst-link");
    std::fs::create_dir_all(&src_link).unwrap();
    std::os::unix::fs::symlink("target", src_link.join("link")).unwrap();
    std::fs::create_dir_all(&dst_link).unwrap();
    std::fs::write(dst_link.join("link"), b"taken").unwrap();
    assert!(matches!(
        copy_dir_all(&src_link, &dst_link).unwrap_err(),
        InfraError::Io { .. }
    ));

    // Unreadable source file → copy fails.
    let src_denied = root.join("src-denied");
    let dst_denied = root.join("dst-denied");
    std::fs::create_dir_all(&src_denied).unwrap();
    let secret = src_denied.join("secret");
    std::fs::write(&secret, b"s").unwrap();
    let mut perms = std::fs::metadata(&secret).unwrap().permissions();
    perms.set_mode(0o000);
    std::fs::set_permissions(&secret, perms).unwrap();
    let err = copy_dir_all(&src_denied, &dst_denied);
    let mut restore = std::fs::metadata(&secret).unwrap().permissions();
    restore.set_mode(0o644);
    let _ = std::fs::set_permissions(&secret, restore);
    assert!(matches!(err.unwrap_err(), InfraError::Io { .. }));

    // Unreadable source directory → read_dir fails.
    let src_nodir = root.join("src-nodir");
    std::fs::create_dir_all(&src_nodir).unwrap();
    let mut dperms = std::fs::metadata(&src_nodir).unwrap().permissions();
    dperms.set_mode(0o000);
    std::fs::set_permissions(&src_nodir, dperms).unwrap();
    let err2 = copy_dir_all(&src_nodir, &root.join("dst-nodir"));
    let mut drestore = std::fs::metadata(&src_nodir).unwrap().permissions();
    drestore.set_mode(0o755);
    let _ = std::fs::set_permissions(&src_nodir, drestore);
    assert!(matches!(err2.unwrap_err(), InfraError::Io { .. }));

    let _ = std::fs::remove_dir_all(&root);
}

#[test]
fn fs_path_io_write_to_directory_errors() {
    let dir = tmp_dir("write-dir");
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    assert!(matches!(
        FsPathIo.write_file(&dir, b"nope").unwrap_err(),
        InfraError::Io { .. }
    ));
    let _ = std::fs::remove_dir_all(&dir);
    // Path::new("/") has no parent → skips create_dir_all arm.
    assert!(matches!(
        FsPathIo.write_file(Path::new("/"), b"nope").unwrap_err(),
        InfraError::Io { .. }
    ));
}

#[test]
fn live_git_checkout_failure_after_clone() {
    let repo = tmp_dir("git-co-src");
    let dest = tmp_dir("git-co-dest");
    let _ = std::fs::remove_dir_all(&repo);
    let _ = std::fs::remove_dir_all(&dest);
    std::fs::create_dir_all(&repo).unwrap();
    for args in [
        vec!["init"],
        vec!["config", "user.email", "cov@example.com"],
        vec!["config", "user.name", "cov"],
    ] {
        assert!(Command::new("git").args(&args).current_dir(&repo).status().unwrap().success());
    }
    std::fs::write(repo.join("f.txt"), b"x").unwrap();
    assert!(Command::new("git").args(["add", "f.txt"]).current_dir(&repo).status().unwrap().success());
    assert!(Command::new("git").args(["commit", "-m", "c"]).current_dir(&repo).status().unwrap().success());
    let url = format!("file://{}", repo.display());
    let err = LiveGitFetch.export(&url, "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef", &dest);
    assert!(matches!(err.unwrap_err(), InfraError::Git(_)));
    let _ = std::fs::remove_dir_all(&repo);
    let _ = std::fs::remove_dir_all(&dest);
}
