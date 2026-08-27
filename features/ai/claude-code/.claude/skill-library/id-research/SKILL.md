---
name: id-research
description: >
  ID RESEARCH mode: Gather sufficient context to plan (or debate-only loop).
  Use when exploring a problem space before committing to a plan.
tags: [id-workflow, research, exploration, context-gathering]
---

# ID RESEARCH Mode

## Goal
Gather enough context to plan (or enter debate-only loop).

## Activities
- Spike solutions to understand problem boundaries
- Consult documentation, code, and existing patterns
- Interview stakeholders or review requirements
- Create proofs-of-concept for risky components
- Identify unknowns and risks

## Writes
None (pure learning mode)

## Exit Criteria
Sufficient context exists to:
- Create a reasonable plan with acceptance criteria
- OR determine this is a debate-only exploration (no implementation planned)

Advance to:
- PLAN (if implementation needed)
- Or remain in RESEARCH for debate-only loops

## Practical guidance (session-proven)
- Inventory-type asks: script the scan (temp bash/python via execute_code or
  /tmp script), don't eyeball truncated search output; always intersect with
  `git ls-files` so generated/ignored state dirs (.devenv, .hermes) are
  excluded from scope.
- Read one exemplar per pattern family you'll touch before planning (e.g.
  an existing assay suite when planning tests) — plans grounded in real
  shapes avoid EXECUTE-phase rework.
- Surface plan-breaking unknowns as an explicit user question at the end of
  RESEARCH or inside PLAN (clarify tool): e.g. "app rewrites its own config —
  symlink vs seed?" beats guessing and redoing.