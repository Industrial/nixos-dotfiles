---
slug: dotfiles-excellence
mode: heavy
---

# NixOS Dotfiles Excellence Initiative

## Mission Statement

Transform this NixOS dotfiles repository from a health score of 17/100 into an
exemplary, maintainable, and secure configuration system that serves as a
reference implementation for NixOS dotfiles management. The mission targets
improvements across five orthogonal dimensions: Nix code quality, Rust tool
correctness, developer experience, security posture, and AI/agent toolchain
coherence.

## Background

Static analysis (roam-code, lean-ctx) revealed the following state:

- **Health score: 17/100** — 4 critical issues, 7 warnings, 15 bottlenecks
- **26 dead exports** — 123 lines of dead code, 28 unused assignments
- **Complexity hotspots** — 4 HIGH-severity functions (CC 16-20); worst is
  `parse_args` in sort (CC=20, nesting depth 9)
- **Cargo.nix debt** — generated Cargo.nix files account for the 5 highest
  debt-score files (churn x complexity); these are auto-generated and need a
  systematic generation/regeneration strategy
- **Neovim language-support.nix** — highest human-authored debt file (21
  commits, 136 coupling partners, complexity 11.6)
- **Test coverage** — TESTING.md mandates 95%+ line/function/branch coverage
  but no CI gate enforces this today; `tests/` directory is empty
- **Maestro setup incomplete** — `.maestro/missions/` and `docs/principles/`
  were missing; no principles seeded
- **README discrepancies** — `hosts/huginn` described as "Server" but is a
  tablet (StarLite 5); `config/` directory referenced but does not exist
- **Documentation globally disabled** — `features/nixos/default.nix` disables
  all NixOS docs to paper over a Python 3.12 docs-build failure; the root cause
  should be fixed instead
- **`allowBroken = true`** — temporarily set in `nixpkgs.config`; should be
  removed once the root cause is addressed
- **`mcp-searxng` feature is empty** — the directory exists with no files;
  either implement it or remove it
- **`tests/` and `schemas/` directories are empty** — no integration tests, no
  schema validation
- **Roam index is stale** — 66h old; a fresh index would give more accurate
  metrics

## Acceptance Criteria (Mission-Level)

1. Roam health score >= 50/100 after all tasks ship
2. Zero dead exports (all 15 safe candidates removed)
3. All 4 HIGH-complexity functions refactored to CC <= 10
4. CI enforces `cargo test` and `cargo clippy -D warnings` on every PR
5. README accurately describes all hosts and reflects real directory structure
6. `allowBroken = false` and documentation re-enabled (or root cause documented
   with a tracking issue)
7. `mcp-searxng` feature either fully wired or cleanly removed
8. At least one principle seeded in `docs/principles/`
9. Maestro config.yaml present

## Workstreams

### WS-1 Foundation (no code dependencies, do first)
- Refresh the roam index
- Seed Maestro config and principles
- Fix README inaccuracies

### WS-2 Dead Code Elimination (depends on WS-1 for fresh index)
- Remove all 15 safe dead exports from Rust tools
- Clear 28 unused variable assignments

### WS-3 Complexity Reduction (depends on WS-2 for stable symbol graph)
- Refactor the 4 HIGH-CC functions in sort, head, wc
- Extract shared `parse_args` logic into rust/common/utils

### WS-4 CI & Quality Gates (can run parallel to WS-2/WS-3)
- Add `cargo test` job to CI
- Add `cargo clippy` job to CI
- Wire Cargo.nix regeneration check

### WS-5 Nix Hygiene (can run parallel to WS-2/WS-3)
- Fix `allowBroken` / documentation-disabled root cause or document with issue
- Implement or remove mcp-searxng feature
- Fix README host descriptions

### WS-6 AI Toolchain Coherence (depends on WS-1)
- Audit AI features for completeness (mcp-searxng, maestro wiring)
- Ensure all MCP servers referenced in hermes-agent/default.nix are present
