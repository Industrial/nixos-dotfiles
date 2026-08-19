---
name: id-workflow
category: workflow
description: >
  Industrial Delivery (ID) workflow - mode-gated agent pipeline using Maestro as the exclusive tracker.
  Use for structured execution of non-trivial tasks requiring research, planning, implementation, review, and shipping.
  Requires declaring [ID:<MODE>] and lane:<tiny|normal|heavy> in every agent response.
tags: [workflow, maestro, industrial-delivery, process, execution]
---

# Industrial Delivery (ID) Workflow

A mode-gated agent pipeline that uses Maestro as the exclusive tracker for work state. 
This workflow ensures disciplined progression through research, planning, execution, review, and shipping phases
with explicit human gates and quality controls.

## Mode Machine
```
ORIENT → RESEARCH → PLAN → EXECUTE → REVIEW → SHIP
         ↑______________|         ↑____FAIL____|
```

## Core Principles

1. **Maestro is the only tracker** - No parallel tracking systems (no BMAD stories, RIPER memory-banks, or markdown TODOs)
2. **Explicit mode declaration** - Every response must declare current mode and lane
3. **Human gates** - Explicit approval required to advance from PLAN to EXECUTE
4. **Write bans** - Strict limitations on what can be modified in each mode
5. **Quality focus** - Correctness prioritized over brevity
6. **Compose, don't duplicate** - Leverage existing skills rather than recreating functionality

## Mode Definitions & Permitted Writes

| Mode | Writes Permitted | Exit Criteria |
|------|------------------|---------------|
| **ORIENT** | none | Ask sharpened; skills/agent selected; lane set |
| **RESEARCH** | none | Sufficient context to plan (or debate-only loop) |
| **PLAN** | Maestro/spec/plan artifacts only (.maestro/**, .cursor/plans/**, specs) | Human approves plan |
| **EXECUTE** | contract-scoped code only | Task done + evidence recorded for all quality gates |
| **REVIEW** | evidence notes only (via maestro evidence record) | Verdict PASS → SHIP; FAIL → EXECUTE |
| **SHIP** | git/gh operations only | Pushed + session-close complete (git status clean) |

## Hard Rails (Protocol Rules)

1. **Declare mode every response**: First line `[ID:<MODE>]` then `lane:<tiny|normal|heavy>`
2. **Write ban**: No code/config edits outside EXECUTE/SHIP. PLAN may write `.maestro/**`, `.cursor/plans/**`, specs only.
3. **Human gate**: Do not enter EXECUTE until user explicitly approves the plan.
4. **Exit criteria**: Satisfy mode-specific checklist before advancing.
5. **Quality floor**: Correctness > brevity. Sharpen ambiguous asks using `/quality`.
6. **No parallel trackers**: No BMAD stories, RIPER memory-banks, or markdown TODOs — Maestro `tsk-`/`pln-` only.
7. **Compose, do not duplicate**: 
   - PLAN delegates to planning skills (e.g., `/plan-hierarchically`)
   - EXECUTE uses Maestro claim→verify→ship + Definitively gates
8. **No Maestro worktrees**: Claim with CLI `--skip-worktree` only. Stay on current branch.

## Mode → Agent Mapping

| Mode | Default Agent Role |
|------|-------------------|
| ORIENT / RESEARCH | `agent-researcher` |
| PLAN | `agent-architect` |
| EXECUTE | `agent-implementer` |
| REVIEW / SHIP | `agent-reviewer` |

## Lane System

Determines workflow routing based on task size and clarity:

### Tiny Lane
- Small, clear-cut changes where files are known
- Routing: `tiny` + clear → brief RESEARCH or EXECUTE if files known
- Otherwise → RESEARCH

### Normal Lane
- Standard features, bug fixes, or moderate changes
- Routing: `normal` → RESEARCH → PLAN → EXECUTE → REVIEW → SHIP

### Heavy Lane
- Large features, refactors, or high-risk changes
- Requires threat-model evidence for critical/security work
- Routing: `heavy` → RESEARCH → PLAN → EXECUTE → REVIEW → SHIP

Set lane during ORIENT via:
- Estimation based on task familiarity
- Data-driven: `maestro intake --paths <comma-separated-paths>`

## Integration with Maestro

This workflow uses Maestro exclusively for tracking work state:

### Task Lifecycle
1. **Spec creation** (PLAN mode): 
   - `maestro spec validate .maestro/specs/<slug>.md`
2. **Mission/task materialization** (PLAN→EXECUTE transition):
   - Heavy mode: `maestro mission from-spec` → `maestro mission decompose`
   - Light mode: `maestro task from-spec`
3. **Execution** (EXECUTE mode):
   - `maestro task claim <id> --skip-worktree`
   - Implement only contract-scoped changes
   - `maestro evidence record` after each quality gate
   - `maestro verdict request` when ready
4. **Verification** (REVIEW mode):
   - `maestro verdict show` to confirm PASS/FAIL
5. **Shipping** (SHIP mode):
   - `maestro task ship <id>` when verdict PASS
   - `git pull --rebase && git push`
   - Final verification: `git status` shows clean working tree

## Usage

This skill provides the ID workflow framework. To use:

1. **Internalize the protocol**: Memorize the mode declarations, write bans, and exit criteria
2. **Follow the mode progression**: Advance only when exit criteria are met
3. **Leverage existing skills** for mode-specific activities:
   - ORIENT: Use clarification and skills inventory skills
   - RESEARCH: Use investigation and spike skills
   - PLAN: Use spec authoring and planning skills
   - EXECUTE: Use implementation and testing skills
   - REVIEW: Use verification and evidence collection skills
   - SHIP: Use git/release skills
4. **Track progress in Maestro**: Use Maestro CLI for task claiming, evidence recording, verdict requests, and shipping
5. **Declare modes explicitly**: Begin every response with `[ID:<MODE>]` and `lane:<X>`

## Anti-patterns (Do Not)

- Implementing during RESEARCH or PLAN modes
- Skipping PLAN on `heavy` lane without explicit user approval
- Claiming Maestro tasks without first showing the contract
- Advancing modes without satisfying exit criteria
- Writing outside permitted files for current mode
- Creating parallel tracking systems (use Maestro exclusively)
- Treating Maestro as merely a task list — it's the exclusive source of work state
- Forgetting to declare mode and lane in every response

## Relationship to Other Skills

This workflow skill orchestrates other skills:
- **ORIENT** mode → Skills for clarification, inventory, and planning
- **RESEARCH** mode → Skills for investigation, spike solutions, and prototyping
- **PLAN** mode → Skills for spec authoring, task breakdown, and architecture
- **EXECUTE** mode → Skills for implementation, testing, and debugging
- **REVIEW** mode → Skills for verification, evidence evaluation, and retrospectives
- **SHIP** mode → Skills for git operations, release management, and deployment

When entering this workflow, the agent should:
1. Declare `[ID:ORIENT]` and set appropriate lane
2. Load relevant mode-specific skills as needed
3. Follow the mode progression with explicit declarations
4. Use Maestro as the sole source of truth for work tracking