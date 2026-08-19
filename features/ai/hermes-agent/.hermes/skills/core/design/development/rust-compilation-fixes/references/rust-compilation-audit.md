# Rust Compilation Audit — solana-yield-optimizer

## Error Breakdown (182 total)

### E0308 — Type Mismatch (156)
`logger_only_context()` returns `Env` (= `RootCliEnv` = `()`), but many test sites call functions
whose `R` generic param is `CapList` (from `caps!(EffectLoggerKey)`).
Fix: Replace `logger_only_context()` with `logger_caps()` where target function R=CapList.

### E0107 — Wrong Generic Arg Count (15)
`succeed`, `from_paper_or_live`, `portfolio_timeline`, `historical_candles`, 
`cooperative_sleep_or_cancelled`, `generate_cpcv_folds`, `tempdir_for_session`

### E0425 — Cannot Find Value (6)
`RootCliEnv`, `ServiceEnv`, `EffectLogKey`, `pipeline_kelly_root_context`, `pipeline_kelly_cpcv_caps`

### E0599 — Method Not Found (4)
Missing `use chrono::Timelike;` and `use id_effect::FromEnv;`

### E0432 — Cannot Find Module (1)

## Helper Functions (from src/lib.rs)
- `logger_only_context()` -> Env (= RootCliEnv = ())
- `logger_caps()` -> CapList with EffectLoggerKey