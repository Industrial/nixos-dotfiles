---
name: id-effect-migration
category: project-infrastructure
description: >
  Captures the id_effect v2→v3 API migration pattern for the solana-yield-optimizer
  project. Centralizes knowledge of breaking changes so future sessions can resolve
  remaining compilation errors efficiently.
tags:
  - id_effect
  - rust
  - migration
  - build-fix
  - test-infrastructure
---

# id_effect Migration (v2 → v3 API Changes)

## Breaking Changes

| Old API | New API | Location |
|---------|---------|----------|
| `id_effect::ServiceEnv` | Removed entirely | `id_effect` crate |
| `id_effect::service_env()` | Removed entirely | `id_effect` crate |
| `id_effect_logger::EffectLogKey` | `id_effect_logger::EffectLoggerKey` | `id_effect_logger` crate |
| `run_test(effect, env: Env)` | `run_test(effect, caps: CapList)` | `id_effect` crate |
| `logger_only_context() -> Env` | `logger_caps() -> LoggerCaps` | `test_effect_logger_env` hub |
| `pipeline_kelly_root_context()` | `pipeline_kelly_caps()` | `composition` module |
| `pipeline_kelly_cpcv_caps()` | `pipeline_kelly_caps()` | `composition` module |

## Central Hub

`src/lib.rs` → `pub(crate) mod test_effect_logger_env`

This module is the single source of truth for test capability wiring. It provides:
- `logger_only_env() -> Env` — raw env, kept for flexibility
- `logger_caps() -> crate::composition::LoggerCaps` — correct argument for `run_test`

## Fix Patterns

### Pattern 1: `run_test` with wrong second argument
```rust
// BEFORE (broken)
run_test(some_effect, logger_only_env())
run_test(some_effect, logger_only_context())
// AFTER
run_test(some_effect, logger_caps())
```

### Pattern 2: `service_env` / `ServiceEnv` removal
```rust
// BEFORE: use id_effect::{run_blocking, service_env};
// AFTER:  use id_effect::run_blocking;
// Replace: let env: ServiceEnv<...> = service_env(...)
// With:    let caps: crate::composition::LoggerCaps = crate::test_effect_logger_env::logger_caps()
```

### Pattern 3: `EffectLogKey` → `EffectLoggerKey`
```rust
// BEFORE: use id_effect_logger::EffectLogKey;
// AFTER:  use id_effect_logger::EffectLoggerKey;
```

### Pattern 4: Missing `RootCliEnv` import
```rust
// Add RootCliEnv to crate::composition import
```

### Pattern 5: Extra `crate::` in path to `test_effect_logger_env`
```rust
// BEFORE (broken)
crate::composition::crate::test_effect_logger_env::logger_caps()
```

// AFTER
crate::composition::test_effect_logger_env::logger_caps()
// Note: The module `test_effect_logger_env` is defined in `src/lib.rs` at the crate root.
// If you see an extra `crate::` in the path, remove it to fix the path.
// Note: This module is only available in tests ([cfg(test)]). For non-term code, 
//       use the appropriate non-test mechanism for obtaining logger capabilities.
```

## Status

Fixed: `src/lib.rs`, `kelly_service_live.rs`, `cli_service_live.rs`
Pending: `pipeline.rs`, `strategy_service_timesfm.rs`, `lightgbm/` test sections
Build: `lightgbm3-sys` also needs libclang at `/nix/store/j1jg0mh9frrc1gwkh6ii1n2fs4jfn2hv-clang-19.1.7-lib/lib`