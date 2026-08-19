---
name: id-orient
description: >
  ID ORIENT mode: Sharpen the ask, pick skills and agent, set lane.
  Use when starting a new task or when needing to clarify requirements.
tags: [id-workflow, orient, planning, clarification]
---

# ID ORIENT Mode

## Goal
Sharpen the ask; pick skills and agent; set lane.

## Steps
1. Restate the ask in its sharpest correct form (use `/quality`)
2. Review available skills; list which are relevant vs which will be used
3. Select agent rule: researcher | architect | implementer | reviewer
4. Set lane via `maestro intake` or estimation (see lanes skill)
5. Load ID protocol hard rails

## Writes
None (preparation mode only)

## Exit Criteria
Satisfy orient-exit checklist:
- Ask is sharpened to its most correct form
- Relevant skills have been considered and selected
- Agent rule is chosen based on task type
- Lane is set (tiny/normal/heavy)
- ID protocol constraints are understood

Then:
- `tiny` + clear → brief RESEARCH or EXECUTE if files known
- else → RESEARCH