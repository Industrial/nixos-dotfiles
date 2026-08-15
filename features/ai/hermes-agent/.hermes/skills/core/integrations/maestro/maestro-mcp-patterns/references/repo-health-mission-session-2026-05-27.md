# Repo Health Analysis -> Maestro Mission (session 2026-05-27)

## Task
"Use Maestro MCP and other MCP servers to make a plan to make this repository
the best you can."

## Repos involved
/home/tom/.dotfiles — NixOS dotfiles, 473 files, health score 17/100

## Tools run in parallel (first wave)
- mcp_maestro_maestro_setup_check
- mcp_roam_code_roam_understand (root=/home/tom/.dotfiles)
- mcp_lean_ctx_ctx_tree (depth=3)

## Tools run in parallel (second wave)
- mcp_roam_code_roam_health
- mcp_roam_code_roam_dead_code
- mcp_roam_code_roam_complexity_report (threshold=10)
- mcp_lean_ctx_ctx_read README.md (mode=full)
- mcp_lean_ctx_ctx_read TODO.md (mode=full)

## Key findings (condensed)

| Signal | Value |
|--------|-------|
| Health score | 17/100 |
| Dead exports | 26 (15 safe, 1 review) |
| Unused assignments | 28 |
| HIGH-CC functions | 4 (CC 16-20) |
| Worst function | sort/parse_args CC=20, nesting depth 9 |
| Debt hotspots | Cargo.nix files (auto-generated, top 5) |
| neovim/language-support.nix | 21 commits, 136 coupling partners |
| Roam index age | 66h stale |

## Errors hit

1. `maestro_mission_from_spec` returned MISSION_CREATE_FAILED because the spec
   frontmatter lacked `acceptance_criteria` as a string array.
   Fix: used `maestro_mission_new(mode="bare") + maestro_mission_decompose`.

2. `maestro_setup_check` reported `.maestro/missions/` and `docs/principles/`
   as MISSING. Fix: `mkdir -p .maestro/missions docs/principles`.

3. `maestro_contract_amend` on a decomposed task returned CONTRACT_NOT_FOUND.
   Accepted as a known limitation; skipped contract for this task, recorded
   evidence via `maestro_evidence_record` instead.

## Output artifacts

- docs/specs/dotfiles-excellence.md
- .maestro/config.yaml (quality gates + policy thresholds)
- docs/principles/nix-module-isolation.md
- docs/principles/rust-tools-cc-ceiling.md
- docs/principles/no-dead-exports.md
- Mission pln-mpnt1tse-drnl3i with 10 tasks in 6 workstreams
- Commit 094bcc340 pushed to feat/lean-ctx-mcp-hermes-support

## Workstream structure used

WS-1 Foundation (must be first, no deps)
  1a: roam reindex
  1b: maestro seed (DONE this session)
  1c: README fixes

WS-2 Dead code (depends on fresh index from WS-1a)
WS-3 Complexity (depends on WS-2 for stable symbol graph)
WS-4a/4b CI gates (parallel with WS-2/WS-3)
WS-5a/5b Nix hygiene (parallel with WS-2/WS-3)
WS-6 AI toolchain audit (depends on WS-1)
