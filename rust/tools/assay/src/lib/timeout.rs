//! Deterministic timeouts and flaky-eval retry via [`TestClock`].

use std::time::{Duration, Instant};

use id_effect::{
    Clock, Effect, Exit, Needs, Schedule, TestClock, fail, retry_with_clock, run_test_with_clock,
    succeed,
};

use crate::caps::{AssayEnv, ClockKey};
use crate::claims::{Claim, interpret_claim};
use crate::verdict::{CaseVerdict, InfraError};

/// Default retry budget when [`crate::run::RunOptions::retry_flaky_eval`] is enabled.
pub const FLAKY_EVAL_RETRY_ATTEMPTS: usize = 2;

/// Wrap `claim` with optional flaky-eval retry driven by the injected clock (never wall time).
pub fn interpret_claim_with_retry(
    claim: Claim,
    retry: bool,
) -> Effect<CaseVerdict, InfraError, AssayEnv> {
    if !retry {
        return interpret_claim(claim);
    }
    Effect::new_async(move |env: &mut AssayEnv| {
        let clock = Needs::<ClockKey>::need(env).clone();
        Box::pin(async move {
            let mut attempt = 0_u64;
            loop {
                match interpret_claim(claim.clone()).run(env).await {
                    Ok(verdict) => return Ok(verdict),
                    Err(err) if attempt < FLAKY_EVAL_RETRY_ATTEMPTS as u64 => {
                        attempt += 1;
                        clock
                            .sleep(Duration::from_millis(1))
                            .run(&mut ())
                            .await
                            .map_err(|_| err)?;
                    }
                    Err(err) => return Err(err),
                }
            }
        })
    })
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;
    use std::sync::atomic::{AtomicUsize, Ordering};

    use id_effect::{Cap, Clock, FromEnv, build_env, run_test, run_test_with_clock};

    use super::*;
    use crate::caps::{AssayEnv, MockNixEval, NixEvaluatorKey, mock_providers};
    use crate::eval::{EvalBackend, EvalResult};
    use crate::verdict::CaseVerdict;

    fn test_env(mock: Arc<MockNixEval>) -> AssayEnv {
        let mut built = build_env(mock_providers()).expect("env");
        built.insert::<Cap<NixEvaluatorKey>>(mock);
        AssayEnv::from_env(built)
    }

    #[test]
    fn retry_with_clock_recovers_after_transient_fail() {
        let clock = TestClock::new(Instant::now());
        let attempts = Arc::new(AtomicUsize::new(0));
        let attempts_c = Arc::clone(&attempts);
        let effect = retry_with_clock(
            move || {
                let n = attempts_c.fetch_add(1, Ordering::SeqCst);
                if n == 0 {
                    fail::<u8, &'static str, ()>("transient")
                } else {
                    succeed::<u8, &'static str, ()>(1)
                }
            },
            Schedule::recurs(2),
            clock.clone(),
            None,
        );
        let exit = run_test_with_clock(effect, (), clock);
        assert_eq!(exit, Exit::succeed(1));
        assert_eq!(attempts.load(Ordering::SeqCst), 2);
    }

    #[test]
    fn schedule_sleep_registers_pending_on_test_clock() {
        let clock = TestClock::new(Instant::now());
        let sleep = clock.sleep(Duration::from_millis(5));
        let _ = id_effect::runtime::run_blocking(sleep, ());
        assert_eq!(clock.pending_sleeps().len(), 1);
    }

    #[test]
    fn interpret_claim_with_retry_disabled_is_single_shot() {
        let mock = Arc::new(MockNixEval::default());
        mock.set("x", EvalResult::Ok(serde_json::json!(1)));
        let env = test_env(mock);
        let claim = Claim::Eq {
            left_expr: "x".into(),
            right_expr: "x".into(),
        };
        let exit = run_test(interpret_claim_with_retry(claim, false), env);
        assert!(matches!(exit, Exit::Success(CaseVerdict::Pass)));
    }

    #[test]
    fn timeout_sleep_advances_without_wall_clock() {
        let clock = TestClock::new(Instant::now());
        let sleep = clock.sleep(Duration::from_millis(10));
        let _ = id_effect::runtime::run_blocking(sleep, ());
        assert_eq!(clock.pending_sleeps().len(), 1);
        clock.advance(Duration::from_millis(10));
        assert!(clock.pending_sleeps().is_empty());
    }

    #[test]
    fn interpret_claim_with_retry_enabled_eventually_passes() {
        use crate::outcome::AssayOutcome;

        let attempts = Arc::new(AtomicUsize::new(0));
        struct FlakyEval {
            attempts: Arc<AtomicUsize>,
        }
        impl EvalBackend for FlakyEval {
            fn eval_json(&self, _expr: &str) -> EvalResult {
                let n = self.attempts.fetch_add(1, Ordering::SeqCst);
                if n == 0 {
                    EvalResult::Err(AssayOutcome::EvalError {
                        kind: "io".into(),
                        message: "flaky".into(),
                        span: None,
                    })
                } else {
                    EvalResult::Ok(serde_json::json!([1, 1]))
                }
            }
        }
        let mut built = build_env(mock_providers()).expect("env");
        built.insert::<Cap<NixEvaluatorKey>>(Arc::new(FlakyEval {
            attempts: Arc::clone(&attempts),
        }));
        let env = AssayEnv::from_env(built);
        let claim = Claim::Eq {
            left_expr: "x".into(),
            right_expr: "x".into(),
        };
        let exit = run_test(interpret_claim_with_retry(claim, true), env);
        assert!(matches!(exit, Exit::Success(CaseVerdict::Pass)));
        assert!(attempts.load(Ordering::SeqCst) >= 2);
    }

    #[test]
    fn interpret_claim_with_retry_exhausts_budget() {
        use crate::outcome::AssayOutcome;

        struct AlwaysIoFail;
        impl EvalBackend for AlwaysIoFail {
            fn eval_json(&self, _expr: &str) -> EvalResult {
                EvalResult::Err(AssayOutcome::EvalError {
                    kind: "io".into(),
                    message: "persistent".into(),
                    span: None,
                })
            }
        }
        let mut built = build_env(mock_providers()).expect("env");
        built.insert::<Cap<NixEvaluatorKey>>(Arc::new(AlwaysIoFail));
        let env = AssayEnv::from_env(built);
        let claim = Claim::Eq {
            left_expr: "a".into(),
            right_expr: "b".into(),
        };
        let exit = run_test(interpret_claim_with_retry(claim, true), env);
        assert!(matches!(exit, Exit::Failure(_)));
    }
}
