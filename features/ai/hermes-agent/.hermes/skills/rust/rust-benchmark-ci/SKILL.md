---
name: rust-benchmark-ci
description: Set up benchmarking in CI for Rust projects using GitHub Actions and criterion.
category: rust
---

# Rust Benchmark CI

This skill covers setting up benchmarking in CI for Rust projects using GitHub Actions and criterion.

## Triggers

- Adding benchmarking to a Rust project
- Setting up CI for Rust projects with benchmarking

## Steps

1. Ensure the project has a `benches` directory and `criterion` in dev-dependencies.
2. Add a benchmark job to the GitHub Actions CI workflow (e.g., .github/workflows/ci.yml):
   - The job should depend on the test job (needs: test)
   - Use the same setup as the test job (actions/checkout, DeterminateSystems/nix-installer-action, dtolnay/rust-toolchain, Swatinem/rust-cache)
   - Run `cargo bench`
   - Upload the benchmark results as an artifact (using actions/upload-artifact) from `target/criterion`
3. Fix common Rust issues that break CI:
   a. Path separators: Replace `std::fs:` and `std::env:` with `std::fs::` and `std::env::`.
   b. Match arms in tests: Change `=> assert_eq!(kind, "X");` to `=> { assert_eq!(kind, "X") },` and similarly for panic! arms.
   c. Test assertions: Change `if let Ok(EvalResult::Ok(value)) = result` to `if let EvalResult::Ok(value) = result`.
   d. Remove unused imports (e.g., unused SimpleNixEval).
   e. Address clippy warnings: Remove needless `return` statements and add `#[allow(clippy::result_unit_err)]` if necessary.
4. Commit and push the changes.

## References

See references/rust-benchmark-ci-session-details.md for session-specific details.