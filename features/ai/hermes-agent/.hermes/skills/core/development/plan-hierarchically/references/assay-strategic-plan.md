# Assay Strategic Plan Summary (Condensed Knowledge Bank)

## Goal
Make Assay the absolute best Nix testing framework by excelling in performance, features, ergonomics, and ecosystem integration.

## Phased Approach

### Phase 1: Performance Micro-optimizations
- Implement optional in-process eval backend for safe, cheap claims (JSON primitives)
- Optimize batching mechanism (persistent nix eval process pool)
- Benchmark and tune batch size
- Explore compiling simple Nix expressions to Rust (JIT/AOT)

### Phase 2: Ecosystem & Packaging
- Write nixpkgs package and submit PR
- Update flake.nix for nixpkgs compatibility
- Create tutorials for Assay in stdenv.mkDerivation
- Engage nixpkgs community to adopt Assay as recommended testing framework

### Phase 3: Migration Tooling
- Develop `assay convert nix-unit` to convert nix-unit test files
- Develop `assay convert runTests` to convert runTests expressions
- Provide compatibility mode to run existing nix-unit tests without conversion

### Phase 4: Benchmarking & Proof
- Expand benchmark suite (latency, memory, mixed throughput, scalability)
- Automate benchmark runs in CI, publish results to dashboard
- Add `assay benchmark` subcommand for local benchmarking
- Regularly compare against nix-unit, runTests, namaka, nixt

### Phase 5: Extend Claim Algebra & Features
- New claims: `assay.moduleEval`, `assay.drvBuild`, `assay.drvOutput`, `assay.property`
- Improve existing claims (e.g., `assay.throws` with multiple patterns, enhanced snapshot)
- Add test fixtures/setup-teardown without breaking isolation

### Phase 6: Replace Nix Built-ins with Rust Equivalents
- Identify bottlenecks (string manipulation, attrset operations) in test suites
- Implement efficient Rust equivalents in existing crates (nixq, nixdrv, ...) or new crates
- Expose Rust functions to Assay DSL via new claim type or helper functions in Nix context

## Success Metrics
- Decision-matrix score (from docs/comparison.md) increases from 4.58 → 4.8+
- Assay packaged in nixpkgs and used by default in new nixpkgs contributions
- Benchmarks show Assay faster than nix-unit for mixed workloads, parity or better for trivial eq
- `assay convert` tools widely adopted, reducing migration effort from hours to minutes

## Immediate Next Steps (from session)
1. Create benchmark automation in CI
2. Begin work on in-process eval backend for trivial eq claims
3. Start packaging work: draft nixpkgs expression for Assay
4. Design conversion tools: sketch interface for `assay convert nix-unit` and `assay convert runTests`