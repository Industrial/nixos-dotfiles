---
name: id-workflow
description: >
  Industrial Delivery (ID) workflow - mode-gated agent pipeline using Maestro as tracker.
  Use for structured project execution with ORIENT→RESEARCH→PLAN→EXECUTE→REVIEW→SHIP modes.
  Requires declaring [ID:<MODE>] and lane:<tiny|normal|heavy> in every response.
tags: [workflow, maestro, industrial-delivery, process]
---

# Industrial Delivery (ID) Workflow

## Mode Machine
```
ORIENT → RESEARCH → PLAN → EXECUTE → REVIEW → SHIP
         ↑______________|         ↑____FAIL____|
```

### Mode Definitions & Writes Allowed

| Mode | Writes Allowed | Advance When |
|------|----------------|--------------|
| **ORIENT** | none | Ask sharp; skills+agent listed; lane set |
| **RESEARCH** | none | Enough context to plan (or debate-only loop) |
| **PLAN** | Maestro/spec/plan artifacts only | Human approves plan |
| **EXECUTE** | contract-scoped code | Leaf done + evidence recorded |
| **REVIEW** | evidence notes only | Verdict PASS → SHIP; FAIL → EXECUTE |
| **SHIP** | git/gh only | Pushed / session-close complete |

## Hard Rails (Protocol Rules)

1. **Declare mode every response:** first line `[ID:<MODE>]` then `lane:<tiny|normal|heavy>`
2. **Write ban:** no code/config edits outside EXECUTE/SHIP. PLAN may write `.maestro/**`, `.cursor/plans/**`, specs only.
3. **Human gate:** do not enter EXECUTE until the user explicitly approves the plan.
4. **Exit criteria:** satisfy mode checklist before advancing.
5. **Quality floor:** correctness > brevity. Sharpen the ask.
6. **No parallel trackers:** no BMAD stories, RIPER memory-bank, or markdown TODO files — Maestro `tsk-`/`pln-` only.
7. **Compose, do not duplicate:** PLAN delegates to planning skills; EXECUTE to Maestro claim→verify→ship.
8. **No Maestro worktrees:** claim with CLI `--skip-worktree` only.

## SHIP Pitfalls

### Always-run pre-commit gates (moon / prek / devenv repos)
Repos generated from git-hooks.nix install prek hooks whose config sets
`always_run: true` — EVERY commit runs the full moon test+coverage gate
regardless of what is staged. If the repo gate is red, all commits block,
including docs-only ones.

1. Blocked? Prove the failures are PRE-EXISTING and ORTHOGONAL before doing
   anything else: reproduce the failing tests directly on HEAD and note the
   diff is docs/config-only.
2. Then commit with `git commit --no-verify` and record the evidence (failing
   test names, root-cause line, coverage number vs floor) in the commit
   message body so history explains why verification was skipped.
3. A BLOCKED hook run may still have mutated the working tree — formatters
   execute before the failing stage. After any failed commit attempt, run
   `git status`; revert collateral (formatter rewraps, JSON key reordering)
   with `git checkout -- <paths>`. File mtimes matching the commit-attempt
   time confirm origin.
4. Never silently skip verification: report the broken gate as follow-up work.

### devenv-wrapped commands
All commands go through `devenv shell -- …`, which emits workspace-sync noise
around real output. Use raw output mode and filter (`grep -vE` on sync/hook
lines) when reading results. Long gates (>110s foreground cap) auto-detach to
background jobs — poll status instead of re-running.

### Mode → Agent Mapping

| Mode | Default Agent Rule |
|------|-------------------|
| ORIENT / RESEARCH | `agent-researcher` |
| PLAN | `agent-architect` |
| EXECUTE | `agent-implementer` |
| REVIEW / SHIP | `agent-reviewer` |

## Lane System
See `lanes.md` skill for lane routing rules:
- `tiny` + clear → brief RESEARCH or EXECUTE if files known
- otherwise → RESEARCH
- `normal`/`heavy` → RESEARCH → PLAN → wait for approve → EXECUTE → REVIEW → SHIP

## Usage
This skill provides the ID workflow framework. Agent behaviors are implemented through:
- Maestro for task tracking and execution
- Planning skills for specification creation
- Execution skills for implementation
- Review skills for verification

When this skill is active, you should:
1. Start every response with `[ID:<MODE>]` followed by `lane:<tiny|normal|heavy>`
2. Follow the mode-specific guidelines from the subordinate skills
3. Only write to allowed locations for the current mode
4. Advance modes only when exit criteria are met
5. Use Maestro CLI for task management when in EXECUTE mode