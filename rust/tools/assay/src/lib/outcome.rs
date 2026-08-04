//! Assay outcome taxonomy — first-class Pass/Fail/EvalError and related exits.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "value", rename_all = "snake_case")]
pub enum AssayOutcome {
    Pass,
    Fail {
        claim: String,
        left: Option<serde_json::Value>,
        right: Option<serde_json::Value>,
        diff: String,
    },
    EvalError {
        kind: String,
        message: String,
        span: Option<String>,
    },
    Recursion,
    Timeout,
    Counterexample {
        seed: u64,
        shrunk: serde_json::Value,
    },
    SnapshotMismatch {
        path: String,
        diff: String,
    },
    ResourceLeak,
}

/// Run a case closure, mapping panics to `EvalError { kind: "panic" }`.
pub fn run_case<F>(f: F) -> AssayOutcome
where
    F: FnOnce() -> AssayOutcome,
{
    match std::panic::catch_unwind(std::panic::AssertUnwindSafe(f)) {
        Ok(outcome) => outcome,
        Err(payload) => AssayOutcome::EvalError {
            kind: "panic".to_string(),
            message: panic_payload_message(&payload),
            span: None,
        },
    }
}

fn panic_payload_message(payload: &Box<dyn std::any::Any + Send>) -> String {
    if let Some(message) = payload.downcast_ref::<&str>() {
        return (*message).to_string();
    }
    if let Some(message) = payload.downcast_ref::<String>() {
        return message.clone();
    }
    "unknown panic".to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn run_case_pass() {
        assert_eq!(run_case(|| AssayOutcome::Pass), AssayOutcome::Pass);
    }

    #[test]
    fn run_case_panic_becomes_eval_error() {
        let outcome = run_case(|| {
            panic!("boom");
        });
        assert_eq!(
            outcome,
            AssayOutcome::EvalError {
                kind: "panic".to_string(),
                message: "boom".to_string(),
                span: None,
            }
        );
    }

    #[test]
    fn run_case_string_panic_payload() {
        let outcome = run_case(|| panic!("{}", "string panic"));
        match outcome {
            AssayOutcome::EvalError { kind, message, .. } => {
                assert_eq!(kind, "panic");
                assert_eq!(message, "string panic");
            }
            other => panic!("expected panic eval error, got {other:?}"),
        }
    }

    #[test]
    fn run_case_unknown_panic_payload() {
        let outcome = run_case(|| {
            std::panic::panic_any(42i32);
        });
        assert_eq!(
            outcome,
            AssayOutcome::EvalError {
                kind: "panic".to_string(),
                message: "unknown panic".to_string(),
                span: None,
            }
        );
    }
}
