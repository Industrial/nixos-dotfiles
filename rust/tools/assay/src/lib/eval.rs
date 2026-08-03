//! Isolated Nix evaluation backends.

use std::io;
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
pub trait EvalBackend {
    fn eval_json(&self, expr: &str) -> EvalResult;
}

/// v0 backend: spawn a fresh `nix eval` process per expression.
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq)]
pub struct ProcessNixEval;

impl EvalBackend for ProcessNixEval {
    fn eval_json(&self, expr: &str) -> EvalResult {
        match run_nix_eval(expr) {
            Ok(value) => EvalResult::Ok(value),
            Err(outcome) => EvalResult::Err(outcome),
        }
    }
}

fn run_nix_eval(expr: &str) -> Result<Value, AssayOutcome> {
    let output = spawn_nix_eval(expr)?;
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
        assert!(matches!(
            thrown,
            EvalResult::Err(AssayOutcome::EvalError { ref kind, .. }) if kind == "throw"
        ));

        let ok = backend.eval_json("1 + 1");
        assert!(matches!(ok, EvalResult::Ok(Value::Number(_))));
    }
}
