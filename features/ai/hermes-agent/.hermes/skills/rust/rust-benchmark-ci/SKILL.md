---
name: rust-benchmark-ci
description: Set up benchmarking in CI for Rust projects using GitHub Actions and criterion.
category: rust
---

# Rust Benchmark CI

This skill covers setting up benchmarking in CI for Rust projects using GitHub Actions and criterion.

## Triggers
# Set up benchmarking in CI for Rust projects using GitHub Actions and criterion.

## Trigger
When you want to add automated benchmarking to a Rust project's CI pipeline that uses criterion for benchmarks.

## Steps
1. **Ensure criterion is in dev-dependencies**: Add criterion to [dev-dependencies] in Cargo.toml.
2. **Create benches directory**: If it doesn't exist, create a benches/ directory at the project root.
3. **Add benchmark files**: Place your benchmark code in benches/ following criterion's conventions.
4. **Modify CI workflow**: Add a benchmark job to your GitHub Actions workflow (e.g., .github/workflows/ci.yml):
   ```yaml
   benchmark:
     needs: test
     runs-on: ubuntu-latest
     steps:
       - uses: actions/checkout@v4
       - uses: DeterminateSystems/nix-installer-action@v16
       - uses: dtolnay/rust-toolchain@stable
       - uses: Swatinem/rust-cache@v2
       - name: Benchmark
         run: cargo bench
       - name: Upload benchmark results
         uses: actions/upload-artifact@v4
         with:
           name: criterion-reports
           path: target/criterion
           if-no-files-found: ignore
   ```
5. **Verify**: Ensure the benchmark job runs after tests and successfully uploads the criterion reports.

## Pitfalls
- **`cargo bench` with no `[[bench]]` targets is a SILENT NO-OP.** It exits 0, runs nothing, and produces no `target/criterion` — so the upload-artifact step then FAILS the job ("no files were found with the provided path"). This shipped broken in the Assay CI (2026-08): `criterion` was in dev-deps but no `benches/` existed. Before wiring a bench job, confirm `grep '\[\[bench\]\]' crates/*/Cargo.toml` (or a `benches/` dir) actually matches something. If benches are aspirational, add `if-no-files-found: ignore` to the upload step so the job stays green until real benches land.
- Make sure the benchmark job has the same setup as other jobs (checkout, nix installer, rust toolchain, rust-cache).
- The benchmark job should depend on the test job (needs: test) to ensure code is tested before benchmarking.
- Ensure the upload-artifact step correctly points to where criterion outputs its reports (usually target/criterion).
- If using a different CI system, adapt the steps accordingly but maintain the same principles: checkout, setup, benchmark, upload.

## Verification
- Check that the benchmark job appears in your CI workflow.
- Verify that when you push changes, the benchmark job runs after the test job.
- Confirm that criterion reports are available as downloadable artifacts in the workflow run.
- Optionally, run cargo bench locally to ensure benchmarks execute correctly.

## References
- criterion documentation: https://docs.rs/criterion
- GitHub Actions workflow syntax: https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions
- actions/upload-artifact: https://github.com/actions/upload-artifact

## Session-Specific Details (Assay Project)
See references/rust-benchmark-ci-assay-session.md for details from the Assay project implementation.