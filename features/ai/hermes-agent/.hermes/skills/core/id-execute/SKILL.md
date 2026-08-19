---
name: id-execute
description: >
  ID EXECUTE mode: Implement contract-scoped code only. Use when building 
  according to approved Maestro plan.
tags: [id-workflow, execution, implementation, coding]
---

# ID EXECUTE Mode

## Goal
Implement contract-scoped code according to approved Maestro plan.

## Activities
- Claim Maestro tasks: `maestro task claim <id> --skip-worktree`
- Implement only what's in the task contract
- Record evidence after each quality gate
- Request verdict when ready: `maestro verdict request`
- Ship completed work: `maestro task ship`

## Writes Allowed
- Contract-scoped code changes only
- No modifications outside EXECUTE/SHIP modes
- All changes must be within task boundaries defined in Maestro contract

## Exit Criteria
For each leaf task:
- Task is done (implementation complete)
- Evidence recorded for all quality gates
- Maestro verdict shows PASS
- Task is shipped: `maestro task ship <id>`

When all tasks in current wave are shipped, advance to REVIEW.