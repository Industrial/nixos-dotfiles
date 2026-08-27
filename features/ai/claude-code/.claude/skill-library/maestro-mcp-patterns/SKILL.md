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

## Task lifecycle: MCP transitions are stricter than the CLI

The MCP transition tools enforce adjacent-state-only moves and reject
jumps the CLI accepts. Real failures (2026-08-25):

- `maestro_task_ship` on a **claimed** task:
  `Invalid task transition claimed -> shipped (allowed from claimed: doing, verifying, blocked, abandoned)`
- `maestro_task_block` on a **draft** task: same error shape (claim first)
- `maestro_task_claim` on a task YOU already claimed:
  `TASK_CLAIM_FAILED` — invalid transition claimed -> claimed

Do NOT burn calls trying to drive the full lifecycle through MCP. The
working hybrid when the repo-pinned `maestro` CLI is available:

1. `maestro_task_claim(id=...)` via MCP or CLI — draft -> claimed
2. CLI: `maestro task verify <tsk-id>` — claimed -> verified -> ready (PASS)
3. CLI: `maestro task ship <tsk-id>` — ready -> shipped

For blocked outcomes: claim first, then
`maestro task block <tsk-id> --reason "..."`.
Evidence recording (`maestro_evidence_record`) works from any non-draft
state.

Note the CLI has NO `task doing` subcommand (2026-08-25): going straight
from claimed to `maestro task verify` works and lands on ready (PASS).
MCP transition tools additionally refuse re-claiming a task you already
hold (claimed -> claimed is invalid), so don't re-claim before shipping.

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

## Multi-repo sessions: the MCP state store binds to ONE project root

The Hermes-launched Maestro MCP server resolves `.maestro/` state relative to
the project root where the Hermes session STARTED — not per-call workdir. When
a session moves to a second repo that has its own Maestro harness:

- Task ids that exist in the target repo's `.maestro/tasks/tasks.jsonl` return
  `TASK_NOT_FOUND` from `maestro_task_get`; `maestro_task_list` shows only the
  launch-root store. NEVER conclude "task doesn't exist" from a cross-root
  TASK_NOT_FOUND — grep the repo's own `.maestro/tasks/tasks.jsonl` first.
- Handoff envelopes are plain JSON — enumerate the target repo's
  `.maestro/handoffs/` newest-first (`ls -t`) and `cat` them directly instead
  of relying on MCP handoff filters.
- For full maestro interaction in the target repo, use the `maestro` CLI
  inside it. Provisioning varies per repo (devenv/nix store paths); check the
  repo's init.sh/devenv.nix before assuming the CLI is absent just because it
  is not on the ambient PATH.

Session detail: [references/multi-repo-mcp-binding.md](references/multi-repo-mcp-binding.md)

---

## See also

- `maestro-mission` -- canonical mission lifecycle (CLI-oriented)
- `maestro-setup` -- bootstrapping the .maestro/ harness
- `maestro-task` -- single task execution loop
