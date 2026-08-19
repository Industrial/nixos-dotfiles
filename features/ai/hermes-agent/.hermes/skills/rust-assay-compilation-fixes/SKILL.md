---
name: rust-assay-compilation-fixes
description: Fixes for common compilation errors in the Assay Rust codebase
---

# Rust Assay Compilation Fixes

## Trigger
When compiling the Assay Rust codebase (`cargo check` or `cargo build`) and encountering errors related to:
- `std::fs:` or `std::env:` with single colon
- `match` arm body without braces
- Incorrect `if let` patterns in tests
- Unused imports
- Clippy warnings like `needless_return` or `result-unit-err`

## Steps
1. **Fix path separators**: Replace `std::fs:` with `std::fs::` and `std::env:` with `std::env::` throughout the codebase.
2. **Fix match arms**: For each test function where you see patterns like:
   ```
   AssayOutcome::EvalError { kind, .. } => assert_eq!(kind, "...");
   other => panic!("expected ..., got {other:?}");
   ```
   Change to:
   ```
   AssayOutcome::EvalError { kind, .. } => { assert_eq!(kind, "...") },
   other => { panic!("expected ..., got {other:?}") },
   ```
3. **Fix test assertions**: Change `if let Ok(EvalResult::Ok(value)) = result {` to `if let EvalResult::Ok(value) = result {`.
4. **Remove unused imports**: Remove imports that are not used (e.g., `SimpleNixEval` if only `eval_simple_expr` is used).
5. **Address clippy warnings**:
   - Remove explicit `return` in `Ok(value) => return EvalResult::Ok(value);` to `Ok(value) => EvalResult::Ok(value);`.
   - For functions returning `Result<Value, ()>`, add `#[allow(clippy::result_unit_err)]` if appropriate, or refactor to avoid early returns.
6. **Reorder expression checking in `simple_eval.rs`**: Check integer literals first, then addition (`split_once(" + ")`), then string literals to avoid misparsing string literals as addition expressions.
7. **Verify**: Run `cargo check --workspace` and `cargo test -p nix-assay --lib` to ensure all tests pass.

## Pitfalls
- The `std::fs:` and `std::env:` errors may appear in multiple files; search globally.
- Match arm fixes must include commas after each arm to avoid syntax errors.
- When fixing `if let` patterns, ensure the enum variant matches exactly.
- Removing unused imports may reveal other missing imports; check for new errors.
- The `simple_eval.rs` reordering is critical: string literal check must come after addition check to correctly parse expressions like `"foo" + "bar"`.
- After refactoring `eval_simple_expr` to avoid early returns, ensure all paths return a `Result`.

## Verification
- Run `cargo check --workspace` should succeed with only warnings (if any).
- Run `cargo test -p nix-assay --lib` should pass all tests.
- Optionally, run the full test suite with `cargo test`.

## References
- See the Assay repository commit history for examples of these fixes.
- Refer to `crates/assay/src/lib/eval.rs` and `crates/assay/src/lib/simple_eval.rs` for before/after examples.