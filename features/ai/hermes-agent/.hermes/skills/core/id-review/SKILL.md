---
name: id-review
description: >
  ID REVIEW mode: Record evidence notes only. Use when verifying completed work.
tags: [id-workflow, review, verification, evidence]
---

# ID REVIEW Mode

## Goal
Record evidence notes only; determine if work is ready to ship.

## Activities
- Review evidence collected during EXECUTE
- Run additional verification if needed
- Determine if verdict should be PASS or FAIL
- Request verdict: `maestro verdict request`
- Show verdict: `maestro verdict show`

## Writes Allowed
- Evidence notes only (via `maestro evidence record`)
- No code or configuration changes

## Exit Criteria
- If Maestro verdict is PASS → advance to SHIP
- If Maestro verdict is FAIL → return to EXECUTE for fixes
- Evidence must support the verdict decision