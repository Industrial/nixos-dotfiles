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