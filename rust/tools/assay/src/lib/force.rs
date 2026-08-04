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
fn check_forces_with_support(support: ForceSupport, paths: &[String]) -> AssayOutcome {
    match support {
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

pub fn check_forces(
    _expr: &str,
    paths: &[String],
    _eval: &dyn EvalBackend,
) -> AssayOutcome {
    check_forces_with_support(force_support(), paths)
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
    fn check_forces_public_entry_uses_unsupported_backend() {
        let eval = NoopEval;
        let out = check_forces("x", &["p".into()], &eval);
        match out {
            AssayOutcome::Fail { .. } => {}
            other => panic!("expected Fail, got {other:?}"),
        }
    }

    #[test]
    fn force_support_is_unsupported() {
        match force_support() {
            ForceSupport::Unsupported(_) => {}
            ForceSupport::Supported => panic!("expected unsupported"),
        }
    }

    #[test]
    fn check_forces_fails_not_pass() {
        let eval = NoopEval;
        let out = check_forces("x", &["a".into()], &eval);
        match out {
            AssayOutcome::Fail { diff, .. } => assert!(
                diff.contains("UNSUPPORTED"),
                "diff must explain unsupported: {diff}"
            ),
            other => panic!("expected Fail, got {other:?}"),
        }
    }

    #[test]
    fn check_forces_supported_backend_branch() {
        let out = check_forces_with_support(ForceSupport::Supported, &["a".into()]);
        match out {
            AssayOutcome::Fail { diff, .. } => assert!(diff.contains("force probe not wired")),
            other => panic!("expected Fail, got {other:?}"),
        }
    }
}
