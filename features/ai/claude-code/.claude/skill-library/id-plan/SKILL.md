---
name: id-plan
description: >
  ID PLAN mode: Create Maestro/spec/plan artifacts only. Use when ready to 
  specify what to build after research is complete.
tags: [id-workflow, planning, specification, maestro]
---

# ID PLAN Mode

## Goal
Create Maestro/spec/plan artifacts only (no implementation code).

## Deliverables
- Maestro mission/spec files (`.maestro/specs/*.md`)
- Maestro execution overlay (for heavy mode): `.maestro/missions/<slug>.execution.md`
- Cursor plan file: `.cursor/plans/<slug>.plan.md`
- Machine-readable plan-check sibling: `.cursor/plans/<slug>.plan-check.yaml`
  (`maestro plan check` validates THIS file, never the human `.plan.md`;
  required keys `intendedFiles`, `proofSet: []`, `riskClass`). Contracts and
  their `dw-*` criterion ids exist only after `task claim`, so the actual
  plan-check invocation happens at wave-0 claim time, not during PLAN.

## Writes Allowed
- `.maestro/**` (specs, missions, execution overlays)
- `.cursor/plans/**` (plan documents)
- `history/<timestamp>-*.md` plan/ledger documents (established repo convention:
  the user asks for dated plan artifacts here, e.g. inventories + test plans)
- Specification files only

## Exit Criteria
Human has explicitly approved the plan (via chat approval).
Plan must satisfy:
- Clear acceptance criteria for each leaf task
- File modifications are specified with purpose
- Diagrams included where needed (flow, sequence, state, ERD)
- Quality gates defined for each task
- Dependencies and wave structure identified

Advance to EXECUTE only after explicit user approval. A `clarify` tool choice
counting as approval must be unambiguous ("Approve — execute…"); treat any
conditional or partial pick as a revision request instead.