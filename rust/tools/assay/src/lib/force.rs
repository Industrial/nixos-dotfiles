//! Force-set coverage claims (`forces paths`).
//!
//! Nix process eval does not expose which thunks were forced during evaluation.
//! [`force_support`] reports that limitation; [`check_forces`] returns **Fail**, never Pass,
//! until a backend can observe forced attrpaths.

use crate::eval::EvalBackend;
use crate::outcome::AssayOutcome;

/// Whether the active evaluator can report forced attribute paths.
#[derive(Debug, Clone, Copy, Eq, PartialEq)]
pub enum ForceSupport {
    Unsupported(&'static str),
    Supported,
}

/// Current force-set probe status for the default process-based Nix evaluator.
pub fn force_support() -> ForceSupport {
    ForceSupport::Unsupported("nix process eval does not expose thunk force sets")
}

/// Verify that evaluating `expr` forced exactly `paths` (best-effort).
///
/// Returns [`AssayOutcome::Pass`] only when the backend supports force probes and the
/// observed set matches. Today always fails with an explicit UNSUPPORTED message.
pub fn check_forces(
    _expr: &str,
    paths: &[String],
    _eval: &dyn EvalBackend,
) -> AssayOutcome {
    match force_support() {
        ForceSupport::Unsupported(reason) => AssayOutcome::Fail {
            claim: "forces".into(),
            left: None,
            right: None,
            diff: format!(
                "UNSUPPORTED: {reason}; cannot verify force set {:?}",
                paths
            ),
        },
        ForceSupport::Supported => AssayOutcome::Fail {
            claim: "forces".into(),
            left: None,
            right: None,
            diff: "force probe not wired for supported backend".into(),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::eval::{EvalBackend, EvalResult};
    use serde_json::json;

    struct NoopEval;

    impl EvalBackend for NoopEval {
        fn eval_json(&self, _expr: &str) -> EvalResult {
            EvalResult::Ok(json!(null))
        }
    }

    #[test]
    fn force_support_is_unsupported() {
        assert!(matches!(force_support(), ForceSupport::Unsupported(_)));
    }

    #[test]
    fn check_forces_fails_not_pass() {
        let eval = NoopEval;
        let out = check_forces("x", &["a".into()], &eval);
        assert!(
            matches!(out, AssayOutcome::Fail { .. }),
            "expected Fail, got {out:?}"
        );
        if let AssayOutcome::Fail { diff, .. } = out {
            assert!(
                diff.contains("UNSUPPORTED"),
                "diff must explain unsupported: {diff}"
            );
        }
    }
}
