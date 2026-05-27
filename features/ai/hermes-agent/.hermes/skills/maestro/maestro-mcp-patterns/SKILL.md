---
name: maestro-mcp-patterns
description: >
  Practical patterns and pitfalls for using Maestro via MCP tools (not the CLI).
  Covers the mission creation path that actually works, contract gotchas, and
  directory prerequisites. Load alongside maestro-mission when the Maestro MCP
  server is the integration point.
---

# Maestro via MCP: Patterns and Pitfalls

The upstream `maestro-mission` skill documents the CLI surface. When Hermes
integrates with Maestro through the MCP server (`mcp_maestro_*` tools), several
behaviors differ. This skill captures those differences and the reliable patterns.

---

## Mission creation: use bare + decompose

`maestro_mission_from_spec` requires the spec frontmatter to include
`acceptance_criteria` as a non-empty **string array**. Specs with prose
acceptance criteria in the body (not frontmatter) return:

  MISSION_CREATE_FAILED: Spec requires acceptance_criteria: non-empty string array

**Always use the two-step bare path via MCP:**

1. `maestro_mission_new(mode="bare", title=..., slug=...)`  -- returns `pln-...`
2. `maestro_mission_decompose(mission_id=..., tasks=[{title, slug, spec_path?}, ...])`

This works for any spec shape and is the default MCP path.

---

## Directory prerequisites

`maestro_setup_check` reports `.maestro/missions/` and `docs/principles/` as
`missing` when absent. MCP tools do NOT create them automatically.

Create them before any mission workflow:

  mkdir -p .maestro/missions docs/principles

`maestro_setup_check` returns `ok: true` only when both directories exist.
`config.yaml` absence is a `warn` (not `error`) -- optional.

---

## Contract and verdict: spec-sourced tasks only

`maestro_contract_amend` and `maestro_verdict_request` return `CONTRACT_NOT_FOUND`
on tasks created via `mission_decompose`. Auto-synthesis only fires for tasks
created with `maestro_task_from_spec`.

If you need contract-gated verdicts on a specific task, create that task with
`maestro_task_from_spec` (pointing at a spec file) rather than including it in
the bulk decompose batch.

---

## Task state before recording evidence

Tasks from `mission_decompose` start in `draft` state. Always claim before
recording evidence:

1. `maestro_task_claim(id=...)` -- advances draft -> claimed
2. `maestro_evidence_record(taskId=..., note=...)` -- then safe to record

---

## Spec location

Place specs under `docs/specs/<slug>.md` (not `.maestro/specs/<slug>.md`).
The CLI default is `.maestro/specs/`, but placing under `docs/specs/` keeps
them alongside principles and in the tracked docs tree.

---

## Repo health analysis -> mission workflow

When the task is "make this repo as good as possible":

1. Run roam_understand + roam_health + roam_dead_code + roam_complexity_report
   in parallel to build a full picture before opening any editor.
2. Read README.md, TODO.md, devenv.nix, key feature default.nix files.
3. Run git log --oneline to understand recent trajectory.
4. Synthesize findings into workstreams (each independent workstream can be
   done in parallel; workstreams with data dependencies must be sequential).
5. Write docs/specs/<slug>.md with background, findings, workstreams, and
   acceptance criteria.
6. maestro_mission_new (bare) + maestro_mission_decompose with one task per
   slice; ~10 tasks is a good ceiling for a 6-workstream health initiative.
7. Immediately complete WS-1 foundation tasks (roam reindex, mkdir, seed
   principles and config.yaml) in the same session so the next agent has
   a clean harness.
8. Commit everything and push before session ends.

---

## See also

- `maestro-mission` -- canonical mission lifecycle (CLI-oriented)
- `maestro-setup` -- bootstrapping the .maestro/ harness
- `maestro-task` -- single task execution loop
