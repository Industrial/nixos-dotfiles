//! Case verdict vs infrastructure error — id_effect `Exit` model (D2).
//!
//! Soft assertion results live in [`CaseVerdict`] as `Exit::Success` payloads.
//! Infrastructure failures are [`InfraError`] wrapped in `Cause::Fail`.
//! Panics and resource leaks map to `Cause::Die`.

use id_effect::{Cause, Exit};
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::outcome::AssayOutcome;

/// Soft domain verdict for a single test case (success payload in `Exit<A, _>`).
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "value", rename_all = "snake_case")]
pub enum CaseVerdict {
    Pass,
    AssertFail {
        claim: String,
        left: Option<Value>,
        right: Option<Value>,
        diff: String,
    },
    EvalThrow {
        kind: String,
        message: String,
    },
    ExpectedThrow,
    SnapshotMismatch {
        path: String,
        diff: String,
    },
    Counterexample {
        seed: u64,
        shrunk: Value,
    },
    Unsupported {
        feature: String,
    },
}

/// Infrastructure / runner failure (typed error in `Cause::Fail`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "value", rename_all = "snake_case")]
pub enum InfraError {
    SuiteLoad(String),
    Capability(String),
    Timeout { case: String, limit_ms: u64 },
    Worker(String),
    Io(String),
}

/// Map legacy [`AssayOutcome`] to `Exit<CaseVerdict, InfraError>`.
pub fn outcome_to_exit(outcome: AssayOutcome) -> Exit<CaseVerdict, InfraError> {
    match outcome {
        AssayOutcome::Pass => Exit::succeed(CaseVerdict::Pass),
        AssayOutcome::Fail {
            claim,
            left,
            right,
            diff,
        } => Exit::succeed(CaseVerdict::AssertFail {
            claim,
            left,
            right,
            diff,
        }),
        AssayOutcome::EvalError {
            kind,
            message,
            span: _,
        } => match kind.as_str() {
            "panic" => Exit::die(message),
            "suite_load" => Exit::fail(InfraError::SuiteLoad(message)),
            "nix_missing" => Exit::fail(InfraError::Capability(message)),
            "io" | "json" => Exit::fail(InfraError::Io(message)),
            "throw" => Exit::succeed(CaseVerdict::EvalThrow { kind, message }),
            _ => Exit::succeed(CaseVerdict::EvalThrow { kind, message }),
        },
        AssayOutcome::Recursion => Exit::succeed(CaseVerdict::EvalThrow {
            kind: "recursion".into(),
            message: "infinite recursion".into(),
        }),
        AssayOutcome::Timeout => Exit::fail(InfraError::Timeout {
            case: String::new(),
            limit_ms: 0,
        }),
        AssayOutcome::Counterexample { seed, shrunk } => {
            Exit::succeed(CaseVerdict::Counterexample { seed, shrunk })
        }
        AssayOutcome::SnapshotMismatch { path, diff } => {
            Exit::succeed(CaseVerdict::SnapshotMismatch { path, diff })
        }
        AssayOutcome::ResourceLeak => Exit::die("resource leak"),
    }
}

/// Map `Exit<CaseVerdict, InfraError>` back to legacy [`AssayOutcome`].
pub fn exit_to_outcome(exit: Exit<CaseVerdict, InfraError>) -> AssayOutcome {
    match exit {
        Exit::Success(verdict) => verdict_to_outcome(verdict),
        Exit::Failure(cause) => infra_cause_to_outcome(&cause),
    }
}

fn verdict_to_outcome(verdict: CaseVerdict) -> AssayOutcome {
    match verdict {
        CaseVerdict::Pass => AssayOutcome::Pass,
        CaseVerdict::AssertFail {
            claim,
            left,
            right,
            diff,
        } => AssayOutcome::Fail {
            claim,
            left,
            right,
            diff,
        },
        CaseVerdict::EvalThrow { kind, message: _ } if kind == "recursion" => {
            AssayOutcome::Recursion
        }
        CaseVerdict::EvalThrow { kind, message } => AssayOutcome::EvalError {
            kind,
            message,
            span: None,
        },
        CaseVerdict::ExpectedThrow => AssayOutcome::Pass,
        CaseVerdict::SnapshotMismatch { path, diff } => {
            AssayOutcome::SnapshotMismatch { path, diff }
        }
        CaseVerdict::Counterexample { seed, shrunk } => {
            AssayOutcome::Counterexample { seed, shrunk }
        }
        CaseVerdict::Unsupported { feature } => AssayOutcome::EvalError {
            kind: "unsupported".into(),
            message: feature,
            span: None,
        },
    }
}

fn infra_cause_to_outcome(cause: &Cause<InfraError>) -> AssayOutcome {
    match cause {
        Cause::Fail(InfraError::SuiteLoad(msg)) => AssayOutcome::EvalError {
            kind: "suite_load".into(),
            message: msg.clone(),
            span: None,
        },
        Cause::Fail(InfraError::Capability(msg)) => AssayOutcome::EvalError {
            kind: "nix_missing".into(),
            message: msg.clone(),
            span: None,
        },
        Cause::Fail(InfraError::Timeout { .. }) => AssayOutcome::Timeout,
        Cause::Fail(InfraError::Worker(msg)) => AssayOutcome::EvalError {
            kind: "worker".into(),
            message: msg.clone(),
            span: None,
        },
        Cause::Fail(InfraError::Io(msg)) => AssayOutcome::EvalError {
            kind: "io".into(),
            message: msg.clone(),
            span: None,
        },
        Cause::Die(message) => {
            if message == "resource leak" {
                AssayOutcome::ResourceLeak
            } else {
                AssayOutcome::EvalError {
                    kind: "panic".into(),
                    message: message.clone(),
                    span: None,
                }
            }
        }
        Cause::Interrupt(_) => AssayOutcome::EvalError {
            kind: "interrupt".into(),
            message: "fiber interrupted".into(),
            span: None,
        },
        Cause::Both(left, _) => infra_cause_to_outcome(left),
        Cause::Then(_, right) => infra_cause_to_outcome(right),
    }
}

impl CaseVerdict {
    /// Wrap this verdict in `Exit::Success`.
    pub fn into_exit(self) -> Exit<CaseVerdict, InfraError> {
        Exit::succeed(self)
    }
}

impl InfraError {
    /// Wrap this error in `Exit::Failure(Cause::Fail(..))`.
    pub fn into_exit(self) -> Exit<CaseVerdict, InfraError> {
        Exit::fail(self)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use id_effect::failure::pretty_exit;
    use serde_json::json;

    #[test]
    fn exit_succeed_pass() {
        let exit = Exit::succeed(CaseVerdict::Pass);
        assert!(matches!(exit, Exit::Success(CaseVerdict::Pass)));
        assert_eq!(exit_to_outcome(exit), AssayOutcome::Pass);
    }

    #[test]
    fn exit_fail_timeout() {
        let exit = Exit::fail(InfraError::Timeout {
            case: "slow_case".into(),
            limit_ms: 5_000,
        });
        let rendered = pretty_exit(&exit);
        assert!(rendered.starts_with("Failure("));
        assert!(rendered.contains("Timeout"));
        assert_eq!(exit_to_outcome(exit), AssayOutcome::Timeout);
    }

    #[test]
    fn outcome_roundtrip_pass() {
        let original = AssayOutcome::Pass;
        let exit = outcome_to_exit(original.clone());
        assert_eq!(exit_to_outcome(exit), original);
    }

    #[test]
    fn outcome_roundtrip_assert_fail() {
        let original = AssayOutcome::Fail {
            claim: "eq".into(),
            left: Some(serde_json::json!(1)),
            right: Some(serde_json::json!(2)),
            diff: "left != right".into(),
        };
        let exit = outcome_to_exit(original.clone());
        assert!(matches!(
            exit,
            Exit::Success(CaseVerdict::AssertFail { .. })
        ));
        assert_eq!(exit_to_outcome(exit), original);
    }

    #[test]
    fn outcome_roundtrip_panic_is_die() {
        let original = AssayOutcome::EvalError {
            kind: "panic".into(),
            message: "boom".into(),
            span: None,
        };
        let exit = outcome_to_exit(original.clone());
        assert!(matches!(exit, Exit::Failure(Cause::Die(_))));
        assert!(pretty_exit(&exit).contains("Die"));
        assert_eq!(exit_to_outcome(exit), original);
    }

    #[test]
    fn outcome_roundtrip_recursion() {
        let original = AssayOutcome::Recursion;
        let exit = outcome_to_exit(original);
        assert_eq!(exit_to_outcome(exit), AssayOutcome::Recursion);
    }

    #[test]
    fn outcome_roundtrip_resource_leak() {
        let original = AssayOutcome::ResourceLeak;
        let exit = outcome_to_exit(original);
        assert_eq!(exit_to_outcome(exit), AssayOutcome::ResourceLeak);
    }

    #[test]
    fn serde_case_verdict_json() {
        let verdict = CaseVerdict::Pass;
        let json = serde_json::to_string(&verdict).unwrap();
        let back: CaseVerdict = serde_json::from_str(&json).unwrap();
        assert_eq!(back, verdict);
    }

    #[test]
    fn serde_infra_error_json() {
        let err = InfraError::Timeout {
            case: "case_a".into(),
            limit_ms: 100,
        };
        let json = serde_json::to_string(&err).unwrap();
        let back: InfraError = serde_json::from_str(&json).unwrap();
        assert_eq!(back, err);
    }
    #[test]
    fn outcome_to_exit_suite_load_and_io_kinds() {
        let suite_err = AssayOutcome::EvalError {
            kind: "suite_load".into(),
            message: "bad".into(),
            span: None,
        };
        assert_eq!(
            exit_to_outcome(outcome_to_exit(suite_err.clone())),
            suite_err
        );

        for kind in ["io", "json"] {
            let err = AssayOutcome::EvalError {
                kind: kind.into(),
                message: "disk".into(),
                span: None,
            };
            let roundtripped = exit_to_outcome(outcome_to_exit(err));
            match roundtripped {
                AssayOutcome::EvalError { kind: k, .. } => assert_eq!(k, "io"),
                other => panic!("expected io eval error, got {other:?}"),
            }
        }

        let nix_err = AssayOutcome::EvalError {
            kind: "nix_missing".into(),
            message: "no nix".into(),
            span: None,
        };
        assert_eq!(exit_to_outcome(outcome_to_exit(nix_err.clone())), nix_err);
    }

    #[test]
    fn outcome_to_exit_throw_counterexample_snapshot() {
        let throw = AssayOutcome::EvalError {
            kind: "throw".into(),
            message: "boom".into(),
            span: None,
        };
        assert!(matches!(
            outcome_to_exit(throw.clone()),
            Exit::Success(CaseVerdict::EvalThrow { .. })
        ));
        assert_eq!(
            exit_to_outcome(outcome_to_exit(throw)),
            AssayOutcome::EvalError {
                kind: "throw".into(),
                message: "boom".into(),
                span: None,
            }
        );

        let cx = AssayOutcome::Counterexample {
            seed: 1,
            shrunk: json!({}),
        };
        assert_eq!(exit_to_outcome(outcome_to_exit(cx.clone())), cx);

        let snap = AssayOutcome::SnapshotMismatch {
            path: "p".into(),
            diff: "d".into(),
        };
        assert_eq!(exit_to_outcome(outcome_to_exit(snap.clone())), snap);
    }

    #[test]
    fn infra_cause_to_outcome_mappings() {
        use id_effect::Cause;
        assert_eq!(
            infra_cause_to_outcome(&Cause::Die("resource leak".into())),
            AssayOutcome::ResourceLeak
        );
        let worker = infra_cause_to_outcome(&Cause::Fail(InfraError::Worker("pool".into())));
        match worker {
            AssayOutcome::EvalError { kind, .. } => assert_eq!(kind, "worker"),
            other => panic!("expected worker, got {other:?}"),
        }
    }

    #[test]
    fn infra_cause_both_then_interrupt_and_die() {
        use id_effect::Cause;
        let pass = Cause::Fail(InfraError::Io("ok".into()));
        // Both/Then prefer left when left is not Pass — here SuiteLoad maps to non-Pass
        let left = Cause::Fail(InfraError::SuiteLoad("bad".into()));
        let right = Cause::Fail(InfraError::Io("disk".into()));
        match infra_cause_to_outcome(&Cause::Both(
            Box::new(left.clone()),
            Box::new(right.clone()),
        )) {
            AssayOutcome::EvalError { kind, .. } => assert_eq!(kind, "suite_load"),
            other => panic!("expected suite_load, got {other:?}"),
        }
        match infra_cause_to_outcome(&Cause::Then(Box::new(left), Box::new(right))) {
            AssayOutcome::EvalError { kind, .. } => assert_eq!(kind, "io"),
            other => panic!("expected io, got {other:?}"),
        }
        match infra_cause_to_outcome(&Cause::Interrupt(id_effect::FiberId::new(1))) {
            AssayOutcome::EvalError { kind, .. } => assert_eq!(kind, "interrupt"),
            other => panic!("expected interrupt, got {other:?}"),
        }
        match infra_cause_to_outcome(&Cause::Die("panic msg".into())) {
            AssayOutcome::EvalError { kind, .. } => assert_eq!(kind, "panic"),
            other => panic!("expected panic, got {other:?}"),
        }
        assert_eq!(
            infra_cause_to_outcome(&Cause::Fail(InfraError::Capability("nix".into()))),
            AssayOutcome::EvalError {
                kind: "nix_missing".into(),
                message: "nix".into(),
                span: None,
            }
        );
        let _ = pass;
    }

    #[test]
    fn verdict_roundtrips_expected_throw_and_unsupported() {
        assert_eq!(
            exit_to_outcome(Exit::succeed(CaseVerdict::ExpectedThrow)),
            AssayOutcome::Pass
        );
        let unsupported = Exit::succeed(CaseVerdict::Unsupported {
            feature: "ifd".into(),
        });
        match exit_to_outcome(unsupported) {
            AssayOutcome::EvalError { kind, .. } => assert_eq!(kind, "unsupported"),
            other => panic!("expected unsupported, got {other:?}"),
        }
        let recursion = Exit::succeed(CaseVerdict::EvalThrow {
            kind: "recursion".into(),
            message: "infinite recursion".into(),
        });
        assert_eq!(exit_to_outcome(recursion), AssayOutcome::Recursion);
    }

    #[test]
    fn into_exit_helpers() {
        assert!(matches!(
            CaseVerdict::Pass.into_exit(),
            Exit::Success(CaseVerdict::Pass)
        ));
        assert!(matches!(
            InfraError::Worker("w".into()).into_exit(),
            Exit::Failure(Cause::Fail(InfraError::Worker(_)))
        ));
    }

    #[test]
    fn outcome_roundtrip_timeout() {
        let exit = outcome_to_exit(AssayOutcome::Timeout);
        assert!(matches!(
            exit,
            Exit::Failure(Cause::Fail(InfraError::Timeout { .. }))
        ));
        assert_eq!(exit_to_outcome(exit), AssayOutcome::Timeout);
    }

    #[test]
    fn assert_fail_with_values_roundtrips() {
        let verdict = CaseVerdict::AssertFail {
            claim: "eq".into(),
            left: Some(json!(1)),
            right: Some(json!(2)),
            diff: "d".into(),
        };
        match exit_to_outcome(Exit::succeed(verdict)) {
            AssayOutcome::Fail { left, right, .. } => {
                assert_eq!(left, Some(json!(1)));
                assert_eq!(right, Some(json!(2)));
            }
            other => panic!("{other:?}"),
        }
    }

    #[test]
    fn serde_all_case_verdict_variants() {
        let variants = vec![
            CaseVerdict::Pass,
            CaseVerdict::AssertFail {
                claim: "eq".into(),
                left: Some(json!(1)),
                right: None,
                diff: "d".into(),
            },
            CaseVerdict::EvalThrow {
                kind: "throw".into(),
                message: "m".into(),
            },
            CaseVerdict::ExpectedThrow,
            CaseVerdict::SnapshotMismatch {
                path: "p".into(),
                diff: "d".into(),
            },
            CaseVerdict::Counterexample {
                seed: 1,
                shrunk: json!(null),
            },
            CaseVerdict::Unsupported {
                feature: "ifd".into(),
            },
        ];
        for verdict in variants {
            let encoded = serde_json::to_string(&verdict).unwrap();
            let decoded: CaseVerdict = serde_json::from_str(&encoded).unwrap();
            assert_eq!(decoded, verdict);
        }
    }

    #[test]
    fn outcome_json_kind_maps_to_io_infra() {
        use id_effect::Cause;
        let err = AssayOutcome::EvalError {
            kind: "json".into(),
            message: "bad json".into(),
            span: None,
        };
        match outcome_to_exit(err) {
            Exit::Failure(Cause::Fail(InfraError::Io(msg))) => assert_eq!(msg, "bad json"),
            other => panic!("{other:?}"),
        }
    }

    #[test]
    fn infra_timeout_cause_roundtrips() {
        let err = InfraError::Timeout {
            case: "slow".into(),
            limit_ms: 50,
        };
        let exit = Exit::fail(err.clone());
        assert_eq!(exit_to_outcome(exit), AssayOutcome::Timeout);
        let json = serde_json::to_string(&err).unwrap();
        let back: InfraError = serde_json::from_str(&json).unwrap();
        assert_eq!(back, err);
    }
}
