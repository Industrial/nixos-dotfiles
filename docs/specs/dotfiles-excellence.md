---
slug: dotfiles-excellence
mode: heavy
---

# NixOS Dotfiles Excellence Initiative

## Mission Statement

Maintain this NixOS dotfiles repository as an exemplary, secure, and agent-friendly
configuration system. Health is tracked with roam-code; target is sustained
90+/100 outside vendored Hermes plugin trees.

## Current State (2026-07-04)

After removing experimental Rust coreutils (cat, cl, head, ls, rev, sort, wc),
pi and VM host setups:

- **Health score: 100/100** — 0 critical issues, quality gate passes
- **498 indexed files, 289 symbols** — 0 dependency cycles
- **Rust workspace:** `oomkiller` only (25 tests passing)
- **Remaining debt hotspots (non-Hermes):**
  - `features/programming/neovim/language-support.nix` (churn × complexity)
  - `rust/tools/oomkiller/Cargo.nix` (auto-generated; regenerate on lock changes)
  - Grafana/monitoring Nix modules (JSON + Nix complexity)

## Completed Milestones

1. Roam health >= 50/100 (achieved 90/100)
2. CI runs `cargo test` and `cargo clippy -D warnings` on every PR
3. README host descriptions accurate (huginn = StarLite tablet)
4. Experimental Rust POSIX tool reimplementations removed
5. Principles seeded in `docs/principles/`
6. Roam index scoped via `.roamignore` (100/100 health on first-party Nix config)

## Remaining Work (excluding Hermes vendored plugins)

1. **Neovim language-support.nix** — reduce coupling and complexity in the
   highest-churn human-authored Nix module
2. **Cargo.nix drift** — CI gate exists; keep oomkiller lockfile and Cargo.nix in sync
3. **`allowBroken` / documentation-disabled** — fix root cause in
   `features/nixos` or document with a tracking issue
4. **Workflow dead symbols** — roam flags YAML job keys in `.github/workflows`;
   keep workflows lean (no commented-out job blocks)
5. **Coverage gates** — TESTING.md describes `moon run :coverage`; wire moon task
   or align docs with `cargo llvm-cov nextest` invocations

## Workstreams

### WS-1 Monitoring & Nix hygiene
- Triage neovim language-support complexity
- Resolve allowBroken / docs-disabled root cause

### WS-2 Rust oomkiller
- Keep CC <= 10 for all functions (`docs/principles/rust-tools-cc-ceiling.md`)
- Zero safe dead exports in `rust/tools/oomkiller`

### WS-3 CI & docs coherence
- Align TESTING.md with actual moon/cargo coverage commands
- Keep excellence spec and roam metrics current after structural changes
