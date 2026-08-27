# ID Workflow Protocol

Industrial Delivery (ID) — mode-gated agent pipeline. Tracker: **Maestro only**.

## Mode machine

```
ORIENT → RESEARCH → PLAN → EXECUTE → REVIEW → SHIP
         ↑______________|         ↑____FAIL____|
```

| Mode | Writes | Advance when |
|------|--------|--------------|
| **ORIENT** | none | Ask sharp; skills+agent listed; lane set (`tiny\|normal\|heavy`) |
| **RESEARCH** | none | Enough context to plan (or debate-only loop) |
| **PLAN** | Maestro/spec/plan artifacts only | Human approves plan |
| **EXECUTE** | contract-scoped code | Leaf done + evidence recorded |
| **REVIEW** | evidence notes only | Verdict PASS → SHIP; FAIL → EXECUTE |
| **SHIP** | git/gh only | Pushed / session-close complete |

Lane skip rules: see [lanes.md](lanes.md).

## Hard rails

1. **Declare mode every response:** first line `[ID:<MODE>]` then `lane:<tiny|normal|heavy>`.
2. **Write ban:** no code/config edits outside EXECUTE/SHIP. PLAN may write `.maestro/**`, `.cursor/plans/**`, specs only.
3. **Human gate:** do not enter EXECUTE until the user explicitly approves the plan (or says plan+implement in one pass).
4. **Exit criteria:** before advancing, satisfy the mode checklist under [checklists/](checklists/).
5. **Quality floor:** correctness > brevity. Sharpen the ask (see `/quality`).
6. **No parallel trackers:** no BMAD stories, RIPER memory-bank, or markdown TODO files for task state — Maestro `tsk-`/`pln-` only.
7. **Compose, do not duplicate:** PLAN delegates to `/plan-hierarchically`; EXECUTE to Maestro claim→verify→ship + Definitively gates.
8. **No Maestro worktrees:** claim with CLI `--skip-worktree` only. Keep all edits on the currently checked-out branch. Never `cd` into `.maestro/worktrees/` paths or sibling `*-tsk-*` trees. Do not use MCP `maestro_task_claim` for claims (it auto-creates heavy-mode worktrees and has no skip flag).

## Mode ↔ agent

| Mode | Default agent rule |
|------|-------------------|
| ORIENT / RESEARCH | `agent-researcher` |
| PLAN | `agent-architect` |
| EXECUTE | `agent-implementer` |
| REVIEW / SHIP | `agent-reviewer` |

## Slash surface

| Command | Effect |
|---------|--------|
| `/id` | ORIENT then auto-route |
| `/id-orient` … `/id-ship` | Jump to named mode |
| `/quality` `/skills` `/agent` `/debate` | Escape hatches; prefer `/id` |

## Anti-patterns

- Implementing during RESEARCH or PLAN
- Skipping PLAN on `heavy` lane
- Claiming Maestro tasks without contract_show
- Claiming via MCP / without `--skip-worktree` (creates worktrees)
- Leaving the current branch for a Maestro-created worktree or `feat/<slug>` claim branch
- Inventing a second issue system
- Advancing modes without checklist pass
