//! Isolated Nix evaluation backends.
//!
//! **Invariant:** `Command::new("nix")` may only appear in this module (Live provider).

use std::io;
use std::path::Path;
use std::process::Command;

use serde_json::Value;

use crate::outcome::AssayOutcome;

/// Result of evaluating a Nix expression to JSON.
#[derive(Debug, Clone, PartialEq)]
pub enum EvalResult {
    Ok(Value),
    Err(AssayOutcome),
}

/// Capability for evaluating Nix expressions in isolation.
pub trait NixEval: Send + Sync {
    fn eval_json(&self, expr: &str) -> EvalResult;
}

/// Back-compat alias during id_effect migration.
pub use NixEval as EvalBackend;

/// v0 Live backend: spawn a fresh `nix eval` process per expression.
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq)]
pub struct ProcessNixEval;

impl NixEval for ProcessNixEval {
    fn eval_json(&self, expr: &str) -> EvalResult {
        match eval_expr_json(expr) {
            Ok(value) => EvalResult::Ok(value),
            Err(outcome) => EvalResult::Err(outcome),
        }
    }
}

/// Evaluate a Nix expression string to JSON.
pub(crate) fn eval_expr_json(expr: &str) -> Result<Value, AssayOutcome> {
    let output = spawn_nix_eval(expr)?;
    if output.status.success() {
        return parse_stdout_json(&output.stdout);
    }
    let stderr = String::from_utf8_lossy(&output.stderr).into_owned();
    Err(classify_stderr(&stderr))
}

/// Evaluate a Nix file to JSON (suite load path).
pub fn nix_eval_file(path: &Path) -> Result<Value, AssayOutcome> {
    let output = spawn_nix_eval_file(path)?;
    if output.status.success() {
        return parse_stdout_json(&output.stdout);
    }
    let stderr = String::from_utf8_lossy(&output.stderr).into_owned();
    Err(classify_stderr(&stderr))
}

fn spawn_nix_eval(expr: &str) -> Result<std::process::Output, AssayOutcome> {
    Command::new("nix")
        .args(["eval", "--impure", "--expr", expr, "--json"])
        .output()
        .map_err(nix_spawn_error)
}

fn spawn_nix_eval_file(path: &Path) -> Result<std::process::Output, AssayOutcome> {
    Command::new("nix")
        .args(["eval", "--impure", "--file"])
        .arg(path)
        .arg("--json")
        .output()
        .map_err(|err| nix_spawn_error_for_path(err, path))
}

fn nix_spawn_error(err: io::Error) -> AssayOutcome {
    if err.kind() == io::ErrorKind::NotFound {
        return AssayOutcome::EvalError {
            kind: "nix_missing".to_string(),
            message: "nix executable not found in PATH".to_string(),
            span: None,
        };
    }
    AssayOutcome::EvalError {
        kind: "io".to_string(),
        message: err.to_string(),
        span: None,
    }
}

fn nix_spawn_error_for_path(err: io::Error, path: &Path) -> AssayOutcome {
    if err.kind() == io::ErrorKind::NotFound {
        return AssayOutcome::EvalError {
            kind: "nix_missing".to_string(),
            message: "nix executable not found in PATH".to_string(),
            span: None,
        };
    }
    AssayOutcome::EvalError {
        kind: "io".to_string(),
        message: format!("run nix eval on {}: {err}", path.display()),
        span: None,
    }
}

fn parse_stdout_json(stdout: &[u8]) -> Result<Value, AssayOutcome> {
    serde_json::from_slice(stdout).map_err(|err| AssayOutcome::EvalError {
        kind: "json".to_string(),
        message: err.to_string(),
        span: None,
    })
}

/// Map `nix eval` stderr to the Assay outcome taxonomy.
pub(crate) fn classify_stderr(stderr: &str) -> AssayOutcome {
    if stderr.contains("infinite recursion") {
        return AssayOutcome::Recursion;
    }
    AssayOutcome::EvalError {
        kind: "throw".to_string(),
        message: stderr.to_string(),
        span: None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::Cell;

    thread_local! {
        static FORCE_SKIP_NIX: Cell<bool> = const { Cell::new(false) };
    }

    fn skip_if_no_nix() -> bool {
        if FORCE_SKIP_NIX.with(|flag| flag.get()) {
            return true;
        }
        Command::new("nix").arg("--version").output().is_err()
    }

    fn run_if_nix(f: impl FnOnce()) {
        if skip_if_no_nix() {
            return;
        }
        f();
    }

    #[test]
    fn classify_infinite_recursion() {
        let stderr = "error: infinite recursion encountered\n";
        assert_eq!(classify_stderr(stderr), AssayOutcome::Recursion);
    }

    #[test]
    fn classify_throw() {
        let stderr = "error: boom\n";
        assert_eq!(
            classify_stderr(stderr),
            AssayOutcome::EvalError {
                kind: "throw".to_string(),
                message: stderr.to_string(),
                span: None,
            }
        );
    }

    #[test]
    #[ignore = "requires nix in PATH"]
    fn nix_throw_isolated_per_call() {
        let backend = ProcessNixEval;
        let thrown = backend.eval_json("builtins.throw \"boom\"");
        match thrown {
            EvalResult::Err(AssayOutcome::EvalError { kind, .. }) => {
                assert_eq!(kind, "throw");
            }
            other => panic!("expected throw, got {other:?}"),
        }

        let ok = backend.eval_json("1 + 1");
        match ok {
            EvalResult::Ok(Value::Number(_)) => {}
            other => panic!("expected number, got {other:?}"),
        }
    }
    #[test]
    fn parse_stdout_json_roundtrip() {
        use serde_json::json;
        let v = parse_stdout_json(br#"{"a":1}"#).expect("parse");
        assert_eq!(v, json!({"a": 1}));
        assert!(parse_stdout_json(b"not json").is_err());
        assert!(parse_stdout_json(b"").is_err());
    }

    #[test]
    fn nix_spawn_error_not_found() {
        use std::io;
        let err = nix_spawn_error(io::Error::new(io::ErrorKind::NotFound, "nix"));
        match err {
            AssayOutcome::EvalError { kind, .. } => assert_eq!(kind, "nix_missing"),
            other => panic!("expected nix_missing, got {other:?}"),
        }
        let err2 = nix_spawn_error(io::Error::new(io::ErrorKind::PermissionDenied, "x"));
        match err2 {
            AssayOutcome::EvalError { kind, .. } => assert_eq!(kind, "io"),
            other => panic!("expected io, got {other:?}"),
        }
    }

    #[test]
    fn nix_spawn_error_for_path_variants() {
        use std::io;
        use std::path::Path;
        let p = Path::new("/no/such/file.nix");
        let err = nix_spawn_error_for_path(io::Error::new(io::ErrorKind::NotFound, "nix"), p);
        match err {
            AssayOutcome::EvalError { kind, .. } => assert_eq!(kind, "nix_missing"),
            other => panic!("expected nix_missing, got {other:?}"),
        }
        let err2 = nix_spawn_error_for_path(io::Error::new(io::ErrorKind::Other, "x"), p);
        match err2 {
            AssayOutcome::EvalError { kind, .. } => assert_eq!(kind, "io"),
            other => panic!("expected io, got {other:?}"),
        }
    }

    #[test]
    fn process_nix_eval_exercises_spawn_path() {
        let backend = ProcessNixEval;
        let _ = backend.eval_json("null");
    }

    #[test]
    fn nix_eval_file_missing_path_returns_err() {
        use std::path::Path;
        let path = Path::new("/tmp/assay-no-such-nix-file-xyz.nix");
        assert!(nix_eval_file(path).is_err());
    }

    #[test]
    fn skip_if_no_nix_true_when_forced() {
        FORCE_SKIP_NIX.with(|flag| flag.set(true));
        assert!(skip_if_no_nix());
        FORCE_SKIP_NIX.with(|flag| flag.set(false));
    }

    #[test]
    fn run_if_nix_noops_when_forced_skip() {
        FORCE_SKIP_NIX.with(|flag| flag.set(true));
        run_if_nix(|| panic!("should not run"));
        FORCE_SKIP_NIX.with(|flag| flag.set(false));
    }

    #[test]
    fn nix_eval_file_succeeds_when_nix_available() {
        run_if_nix(|| {
            let dir = std::env::temp_dir().join(format!("assay-nix-eval-ok-{}", std::process::id()));
            std::fs::create_dir_all(&dir).unwrap();
            let path = dir.join("value.nix");
            std::fs::write(&path, "42").unwrap();
            let value = nix_eval_file(&path).expect("nix eval file");
            assert_eq!(value, serde_json::json!(42));
            let _ = std::fs::remove_dir_all(dir);
        });
    }

    #[test]
    fn eval_expr_json_live_ok_and_throw_stderr() {
        run_if_nix(|| {
            let ok = eval_expr_json("1 + 1").expect("eval");
            assert_eq!(ok, serde_json::json!(2));
            let err = eval_expr_json("builtins.throw \"branch-cov\"").unwrap_err();
            match err {
                AssayOutcome::EvalError { kind, .. } => assert_eq!(kind, "throw"),
                other => panic!("expected throw, got {other:?}"),
            }
        });
    }

    #[test]
    fn nix_eval_file_throw_when_nix_available() {
        run_if_nix(|| {
            let dir = std::env::temp_dir().join(format!("assay-nix-throw-{}", std::process::id()));
            std::fs::create_dir_all(&dir).unwrap();
            let path = dir.join("throw.nix");
            std::fs::write(&path, "builtins.throw \"file-throw\"").unwrap();
            let err = nix_eval_file(&path).unwrap_err();
            match err {
                AssayOutcome::EvalError { kind, .. } => assert_eq!(kind, "throw"),
                other => panic!("expected throw, got {other:?}"),
            }
            let _ = std::fs::remove_dir_all(dir);
        });
    }

}
