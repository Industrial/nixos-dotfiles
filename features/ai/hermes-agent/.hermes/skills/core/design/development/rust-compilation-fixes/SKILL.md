---
name: rust-compilation-fixes
description: >
  Recurring patterns for fixing Rust compilation errors in the solana-yield-optimizer project.
  Covers env type mismatches, generic argument corrections, missing trait imports,
  and module resolution issues specific to the id_effect/effect system.
---

# Rust Compilation Fixes (solana-yield-optimizer)

## Error Taxonomy

| Code | Count | Description |
|------|-------|-------------|
| E0308 | 156 | Type mismatches — wrong env type passed to run_test/run_blocking/run_async |
| E0107 | 15 | Wrong generic arg count on succeed, from_paper_or_live, portfolio_timeline, etc. |
| E0425 | 6 | Cannot find value — missing types/functions in scope |
| E0599 | 4 | Method not found — missing trait import (chrono::Timelike, id_effect::FromEnv) |
| E0432 | 1 | Cannot find module |

## Root Cause: Env Type Mismatch (86% of errors)

Two incompatible helpers are confused:

- **logger_only_context()** → returns Env (= RootCliEnv = ()) — unit type, no capabilities
- **logger_caps()** → returns CapList — carries EffectLoggerKey capability

Effects declared with `caps!(EffectLoggerKey)` (R = CapList) require `logger_caps()` at test sites.
Effects with no caps or `id_effect::NoCaps` accept `logger_only_context()` or `()`.

### Fix Rule

- If the target function's R param = caps!(EffectLoggerKey) → use logger_caps()
- If the target function's R param = id_effect::NoCaps or () → use logger_only_context() or ()

## Generic Arg Count Fixes

- succeed::<A, E, R>() requires exactly 3 type args — add missing ones
- from_paper_or_live::<Spec, Err, Env>() requires 3 type args
- portfolio_timeline and historical_candles may need explicit type annotations
- cooperative_sleep_or_cancelled and tempdir_for_session need correct arg counts

## Missing Imports

- use chrono::Timelike; — needed in runner_service_live.rs, ibkr_gateway_service_live.rs
- use id_effect::FromEnv; — needed where ::FromEnv trait methods are used
- Any missing use for types referenced in error messages

## Files Requiring Fixes

- src/services/cli_service_live.rs — env type and generic arg corrections
- src/services/vendor/ibkr/ibkr_gateway_service_live.rs — missing import + env types
- src/services/vendor/ibkr/ibkr_gateway_service_mock.rs — env type corrections
- src/services/venue_execution/venue_execution_service.rs — env type corrections
- src/services/runner/runner_service_live.rs — missing import + env types
- src/services/strategy/cpcv/cpcv_service_mock.rs — env type corrections
- src/services/strategy/cpcv/tests.rs — env type corrections
- src/services/market_data/market_data_service.rs — env type corrections
- src/domain/action.rs — generic arg fixes on run_test call sites
- src/error.rs — generic arg fixes on succeed() call
- src/domain/portfolio.rs — generic arg + env type fixes
- src/services/strategy/lopezdeprado/pipeline/pipeline.rs — missing test helpers

See also: references/rust-compilation-audit.md