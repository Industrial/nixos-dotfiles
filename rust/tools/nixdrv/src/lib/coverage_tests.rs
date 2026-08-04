//! Integration-style coverage for nixdrv lib paths missed by unit tests.

use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::{Duration, Instant};

use id_effect::{Cap, Clock, Effect, Exit, FromEnv, Needs, build_env, run_test};
use serde_json::{Value, json};

use crate::ca::{FileIngestionMethod, fixed_output_path, text_path};
use crate::caps::{
    DrvSource, DrvSourceKey, FsDrvSource, MockDrvSource, NixdrvEnv, StdClock, live_providers,
    mock_providers,
};
use crate::commands::{
    cmd_parse, cmd_project, cmd_store_path_make_fixed, cmd_store_path_parse, derivation_to_json,
};
use crate::error::{InfraError, ParseError};
use crate::hash::{compress_hash, nix_base32_decode, nix_base32_encode};
use crate::model::{Derivation, DerivationOutput};
use crate::parse_aterm::parse_drv_aterm;
use crate::project::project;
use crate::store_path::{DEFAULT_STORE_DIR, StorePath, parse_store_path};

const SIMPLE_DRV: &str = include_str!("../../fixtures/simple.drv");
const SIMPLE_JSON: &str = include_str!("../../fixtures/simple.json");

fn fixture_path(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("fixtures")
        .join(name)
}

fn env_with(mock: Arc<MockDrvSource>) -> NixdrvEnv {
    let mut raw = build_env(mock_providers()).expect("env");
    raw.insert::<Cap<DrvSourceKey>>(mock as DrvSourceKey);
    NixdrvEnv::from_env(raw)
}

#[test]
fn fs_drv_source_missing_file_errors() {
    let src = FsDrvSource;
    let err = src
        .read(Path::new("/nonexistent/nixdrv-coverage-missing.drv"))
        .unwrap_err();
    assert!(matches!(err, InfraError::Io { .. }));
}

#[test]
fn std_clock_sleep_and_sleep_until_future() {
    let clock = StdClock;
    let exit = run_test(clock.sleep(Duration::from_millis(1)), ());
    assert!(matches!(exit, Exit::Success(())));
    let future = Instant::now() + Duration::from_millis(1);
    let exit = run_test(clock.sleep_until(future), ());
    assert!(matches!(exit, Exit::Success(())));
}

#[cfg(unix)]
#[test]
fn fs_drv_source_reads_stdin_dash() {
    use std::io::Write;
    use std::os::unix::io::AsRawFd;

    unsafe extern "C" {
        fn dup(fd: i32) -> i32;
        fn dup2(fd: i32, fd2: i32) -> i32;
        fn close(fd: i32) -> i32;
    }

    let (reader, mut writer) = std::io::pipe().unwrap();
    writer.write_all(b"Derive").unwrap();
    drop(writer);

    let saved = unsafe { dup(0) };
    assert!(saved >= 0);
    let pipe_fd = reader.as_raw_fd();
    assert_eq!(unsafe { dup2(pipe_fd, 0) }, 0);

    let src = FsDrvSource;
    let bytes = src.read(Path::new("-")).unwrap();
    assert_eq!(bytes, b"Derive");

    unsafe {
        dup2(saved, 0);
        close(saved);
    }
}

#[test]
fn std_clock_now_and_sleep_until_past() {
    let clock = StdClock;
    let _ = clock.now();
    let past = Instant::now() - Duration::from_secs(1);
    let exit = run_test(clock.sleep_until(past), ());
    assert!(matches!(exit, Exit::Success(())));
}

#[test]
fn live_providers_read_temp_file_via_needs() {
    let dir = std::env::temp_dir().join(format!(
        "nixdrv-live-{}-{}",
        std::process::id(),
        Instant::now().elapsed().as_nanos()
    ));
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join("live.drv");
    std::fs::write(&path, b"Derive").unwrap();

    let env = NixdrvEnv::from_env(build_env(live_providers()).expect("env"));
    let effect: Effect<Vec<u8>, InfraError, NixdrvEnv> = Effect::new(move |env| {
        let src = Needs::<DrvSourceKey>::need(env);
        src.read(&path)
    });
    match run_test(effect, env) {
        Exit::Success(bytes) => assert_eq!(bytes, b"Derive"),
        other => panic!("unexpected {other:?}"),
    }
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn store_path_display_format() {
    let sp = StorePath {
        hash: "00000000000000000000000000000000".into(),
        name: "hello".into(),
    };
    assert_eq!(sp.to_string(), "00000000000000000000000000000000/hello");
}

#[test]
fn store_path_rejects_missing_separator() {
    let s = "/nix/store/00000000000000000000000000000000";
    let err = parse_store_path(s, DEFAULT_STORE_DIR).unwrap_err();
    assert!(matches!(err, ParseError::Invalid { .. }));
}

#[test]
fn store_path_rejects_empty_name() {
    let s = "/nix/store/00000000000000000000000000000000-";
    let err = parse_store_path(s, DEFAULT_STORE_DIR).unwrap_err();
    assert!(matches!(err, ParseError::Invalid { .. }));
}

#[test]
fn store_path_rejects_invalid_base32_char() {
    let mut hash = "0".repeat(32);
    hash.replace_range(0..1, "e");
    let s = format!("/nix/store/{hash}-pkg");
    assert!(parse_store_path(&s, DEFAULT_STORE_DIR).is_err());
}

fn simple_drv() -> Derivation {
    let bytes = std::fs::read(fixture_path("simple.drv")).unwrap();
    parse_drv_aterm(&bytes).unwrap()
}

#[test]
fn project_all_scalar_fields() {
    let drv = simple_drv();
    let v = project(
        &drv,
        &[
            "system",
            "platform",
            "builder",
            "args",
            "env",
            "inputSrcs",
            "unknown",
        ],
    );
    assert_eq!(v["system"], "x86_64-linux");
    assert_eq!(v["platform"], "x86_64-linux");
    assert_eq!(v["builder"], "/bin/sh");
    assert!(v["args"].is_array());
    assert!(v["env"].is_object());
    assert!(v["inputSrcs"].is_array());
    assert!(v.get("unknown").is_none());
}

#[test]
fn project_env_dotted_missing_omitted() {
    let drv = Derivation::default();
    let v = project(&drv, &["env.missing"]);
    assert_eq!(v, json!({}));
}

#[test]
fn parse_aterm_outputs_with_hashes_and_inputs() {
    let input = concat!(
        "Derive([",
        "(\"out\",\"/nix/store/x\",\"sha256\",\"deadbeef\"),",
        "(\"dev\",\"/nix/store/y\",\"\",\"\")",
        "],",
        "[(\"/nix/store/dep.drv\",[\"out\",\"dev\"])],",
        "[\"/nix/store/src\"],",
        "\"aarch64-linux\",\"/bin/sh\",[\"-c\",\"build\"],",
        "[(\"name\",\"pkg\"),(\"out\",\"/nix/store/x\")])"
    );
    let drv = parse_drv_aterm(input.as_bytes()).unwrap();
    let out = drv.outputs.get("out").unwrap();
    assert_eq!(out.hash_algo.as_deref(), Some("sha256"));
    assert_eq!(out.hash.as_deref(), Some("deadbeef"));
    assert!(drv.outputs.get("dev").unwrap().hash_algo.is_none());
    assert_eq!(drv.input_drvs.len(), 1);
    assert_eq!(drv.input_srcs, vec!["/nix/store/src"]);
    assert_eq!(drv.args, vec!["-c", "build"]);
    assert_eq!(drv.name(), Some("pkg"));
}

#[test]
fn parse_aterm_string_escapes_newline_tab_and_unknown() {
    let input = br#"Derive([("out","/nix/store/x","","")],[],[],"x86_64-linux","/bin/sh",[],[("name","line1\nline2\ttab\z")])"#;
    let drv = parse_drv_aterm(input).unwrap();
    assert_eq!(
        drv.env.get("name").map(String::as_str),
        Some("line1\nline2\ttab\\z")
    );
}

#[test]
fn parse_aterm_rejects_unexpected_byte() {
    let input = b"Derive([";
    assert!(matches!(
        parse_drv_aterm(input).unwrap_err(),
        ParseError::Unexpected { .. } | ParseError::Eof { .. }
    ));
}

#[test]
fn parse_aterm_whitespace_prefix() {
    let input = b"  Derive([],[],[],\"x86_64-linux\",\"/bin/sh\",[],[(\"name\",\"n\")])";
    let drv = parse_drv_aterm(input).unwrap();
    assert_eq!(drv.name(), Some("n"));
}

#[test]
fn parse_aterm_empty_outputs_and_lists() {
    let input = b"Derive([],[],[],\"x86_64-linux\",\"/bin/sh\",[],[(\"name\",\"n\")])";
    let drv = parse_drv_aterm(input).unwrap();
    assert!(drv.outputs.is_empty());
    assert!(drv.input_drvs.is_empty());
    assert!(drv.input_srcs.is_empty());
}

#[test]
fn parse_aterm_escape_eof_in_string() {
    let input = br#"Derive([("out","/nix/store/x","","")],[],[],"x86_64-linux","/bin/sh",[],[("name","a\"#;
    assert!(matches!(parse_drv_aterm(input).unwrap_err(), ParseError::Eof { .. }));
}

#[test]
fn parse_aterm_rejects_typo_in_derive_prefix() {
    assert!(matches!(
        parse_drv_aterm(b"Derve([])").unwrap_err(),
        ParseError::Unexpected { .. }
    ));
}

#[test]
fn parse_aterm_multiple_input_srcs() {
    let input = br#"Derive([("out","/nix/store/x","","")],[],["/a","/b"],"x86_64-linux","/bin/sh",[],[("name","n")])"#;
    let drv = parse_drv_aterm(input).unwrap();
    assert_eq!(drv.input_srcs, vec!["/a", "/b"]);
}

#[test]
fn parse_aterm_empty_input() {
    assert!(parse_drv_aterm(b"").is_err());
}

#[test]
fn parse_aterm_truncated_after_derive() {
    assert!(parse_drv_aterm(b"Derive").is_err());
}

#[test]
fn parse_aterm_unterminated_string() {
    let input = br#"Derive([],[],[],"x86_64-linux","unclosed"#;
    assert!(parse_drv_aterm(input).is_err());
}

#[test]
fn parse_aterm_escape_sequences() {
    let input = br#"Derive([("out","/nix/store/x","","")],[],[],"x86_64-linux","/bin/sh",[],[("name","a\\b")])"#;
    let drv = parse_drv_aterm(input).unwrap();
    assert_eq!(drv.env.get("name").map(String::as_str), Some("a\\b"));
}

#[test]
fn from_json_rejects_null() {
    assert!(Derivation::from_json(&Value::Null).is_err());
}

#[test]
fn from_json_rejects_array() {
    assert!(Derivation::from_json(&json!([])).is_err());
}

#[test]
fn from_json_empty_object() {
    let drv = Derivation::from_json(&json!({})).unwrap();
    assert!(drv.outputs.is_empty());
    assert!(drv.platform.is_empty());
}

#[test]
fn from_json_bad_output_entry() {
    let v = json!({ "outputs": { "out": 42 } });
    assert!(Derivation::from_json(&v).is_err());
}

#[test]
fn from_json_wrapped_show_bad_inner() {
    let v = json!({ "/nix/store/x.drv": "not-an-object" });
    assert!(Derivation::from_json(&v).is_err());
}

#[test]
fn from_json_eval_like_missing_out_path() {
    let v = json!({ "type": "derivation", "drvPath": "/nix/store/x.drv" });
    assert!(Derivation::from_json(&v).is_err());
}

#[test]
fn from_json_bad_env_value() {
    let v = json!({ "env": { "k": 1 } });
    assert!(Derivation::from_json(&v).is_err());
}

#[test]
fn from_json_bad_array_element() {
    let v = json!({ "args": [1] });
    assert!(Derivation::from_json(&v).is_err());
}

#[test]
fn from_json_output_object_with_hashes() {
    let v = json!({
        "outputs": {
            "out": {
                "path": "/nix/store/out",
                "hashAlgo": "sha256",
                "hash": "abc"
            }
        }
    });
    let drv = Derivation::from_json(&v).unwrap();
    let out = drv.outputs.get("out").unwrap();
    assert_eq!(out.hash_algo.as_deref(), Some("sha256"));
    assert_eq!(out.hash.as_deref(), Some("abc"));
}

#[test]
fn nix_base32_decode_wrong_length() {
    assert!(nix_base32_decode("abc").is_err());
}

#[test]
fn compress_hash_short_digest() {
    let short = [0x01, 0x02, 0x03];
    let c = compress_hash(&short);
    assert_eq!(c[0], 0x01);
    assert_eq!(c[1], 0x02);
    assert_eq!(c[2], 0x03);
}

#[test]
fn nix_base32_encode_padding_branch() {
    let data = [0u8; 20];
    let enc = nix_base32_encode(&data);
    assert_eq!(enc.len(), 32);
    assert!(nix_base32_decode(&enc).is_ok());
}

#[test]
fn text_path_empty_references() {
    let sp = text_path("t", "abc123", &[], DEFAULT_STORE_DIR);
    assert_eq!(sp.name, "t");
    assert_eq!(sp.hash.len(), 32);
}

#[test]
fn fixed_output_both_methods() {
    let digest = [0x22; 32];
    for method in [FileIngestionMethod::Flat, FileIngestionMethod::Recursive] {
        let sp = fixed_output_path("n", method, "sha256", &digest, DEFAULT_STORE_DIR).unwrap();
        assert_eq!(sp.name, "n");
    }
}

#[test]
fn cmd_parse_whitespace_prefixed_json() {
    let mock = Arc::new(MockDrvSource::default());
    mock.set_file("ws.json", b"  {\"outputs\":{\"out\":\"/nix/store/x\"},\"system\":\"x86_64-linux\"}");
    let exit = run_test(cmd_parse(PathBuf::from("ws.json")), env_with(mock));
    match exit {
        Exit::Success(v) => assert_eq!(v["platform"], "x86_64-linux"),
        other => panic!("unexpected {other:?}"),
    }
}

#[test]
fn derivation_to_json_hash_algo_only() {
    let mut drv = Derivation::default();
    drv.outputs.insert(
        "out".into(),
        DerivationOutput {
            path: "/nix/store/x".into(),
            hash_algo: Some("sha256".into()),
            hash: None,
        },
    );
    let v = derivation_to_json(&drv);
    assert_eq!(v["outputs"]["out"]["hashAlgo"], "sha256");
    assert!(v["outputs"]["out"].get("hash").is_none());
}

#[test]
fn from_json_wrapped_show_null_inner() {
    let v = json!({ "/nix/store/x.drv": null });
    assert!(Derivation::from_json(&v).is_err());
}

#[test]
fn from_json_eval_like_out_path_only() {
    let v = json!({
        "outPath": "/nix/store/out",
        "drvPath": "/nix/store/x.drv"
    });
    let drv = Derivation::from_json(&v).unwrap();
    assert_eq!(drv.default_out_path(), Some("/nix/store/out"));
    assert_eq!(drv.platform, "unknown");
}

#[test]
fn model_default_out_path_from_env() {
    let mut drv = Derivation::default();
    drv.env.insert("out".into(), "/nix/store/from-env".into());
    assert_eq!(drv.default_out_path(), Some("/nix/store/from-env"));
}

#[test]
fn cmd_parse_stdin_json() {
    let mock = Arc::new(MockDrvSource::default());
    mock.set_stdin(SIMPLE_JSON.as_bytes());
    let exit = run_test(cmd_parse(PathBuf::from("-")), env_with(mock));
    match exit {
        Exit::Success(v) => assert_eq!(v["name"], "simple-1.0"),
        other => panic!("unexpected {other:?}"),
    }
}

#[test]
fn cmd_parse_bad_json_fails() {
    let mock = Arc::new(MockDrvSource::default());
    mock.set_file("bad.json", b"not json");
    let exit = run_test(cmd_parse(PathBuf::from("bad.json")), env_with(mock));
    assert!(matches!(exit, Exit::Failure(_)));
}

#[test]
fn cmd_store_path_parse_fails() {
    let exit = run_test(
        cmd_store_path_parse("/tmp/not-store".into()),
        env_with(Arc::new(MockDrvSource::default())),
    );
    assert!(matches!(exit, Exit::Failure(_)));
}

#[test]
fn cmd_store_path_make_fixed_unknown_method() {
    let exit = run_test(
        cmd_store_path_make_fixed(
            "pkg".into(),
            "nar".into(),
            "sha256".into(),
            "11".repeat(32),
            None,
        ),
        env_with(Arc::new(MockDrvSource::default())),
    );
    assert!(matches!(exit, Exit::Failure(_)));
}

#[test]
fn cmd_store_path_make_fixed_bad_hex() {
    let exit = run_test(
        cmd_store_path_make_fixed(
            "pkg".into(),
            "flat".into(),
            "sha256".into(),
            "zz".into(),
            None,
        ),
        env_with(Arc::new(MockDrvSource::default())),
    );
    assert!(matches!(exit, Exit::Failure(_)));
}

#[test]
fn derivation_to_json_with_output_hashes() {
    let mut drv = Derivation::default();
    drv.outputs.insert(
        "out".into(),
        DerivationOutput {
            path: "/nix/store/x".into(),
            hash_algo: Some("sha256".into()),
            hash: Some("abc".into()),
        },
    );
    let v = derivation_to_json(&drv);
    assert_eq!(v["outputs"]["out"]["path"], "/nix/store/x");
    assert_eq!(v["outputs"]["out"]["hashAlgo"], "sha256");
    assert_eq!(v["outputs"]["out"]["hash"], "abc");
}

#[test]
fn cmd_project_unknown_field_ignored() {
    let mock = Arc::new(MockDrvSource::default());
    mock.set_file("simple.drv", SIMPLE_DRV.as_bytes());
    let exit = run_test(
        cmd_project(PathBuf::from("simple.drv"), vec!["nope".into()]),
        env_with(mock),
    );
    match exit {
        Exit::Success(v) => assert_eq!(v, json!({})),
        other => panic!("unexpected {other:?}"),
    }
}

#[test]
fn parse_error_eof_and_invalid_display() {
    let eof = ParseError::Eof { offset: 3 };
    assert!(eof.to_string().contains("offset 3"));
    let inv = ParseError::Invalid {
        offset: 1,
        what: "x".into(),
        message: "m".into(),
    };
    assert!(inv.to_string().contains("invalid x"));
}
