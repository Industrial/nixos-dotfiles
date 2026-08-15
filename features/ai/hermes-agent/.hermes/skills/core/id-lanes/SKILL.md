---
name: id-lanes
description: >
  ID lane routing rules: determines how to route tasks based on size and clarity.
  Use with maestro intake to set appropriate lane (tiny/normal/heavy).
tags: [id-workflow, lanes, routing, task-sizing]
---

# ID Lane System

## Lane Definitions

### Tiny Lane
- Small, clear-cut changes
- Files are known and well-understood
- Minimal research needed
- Routing: `tiny` + clear → brief RESEARCH or EXECUTE if files known

### Normal Lane
- Standard feature or bug fix
- Requires research and planning
- Moderate complexity
- Routing: `normal` → RESEARCH → PLAN → EXECUTE → REVIEW → SHIP

### Heavy Lane
- Large feature, refactor, or system change
- Significant research and planning needed
- High complexity or risk
- Routing: `heavy` → RESEARCH → PLAN → EXECUTE → REVIEW → SHIP
- Requires threat-model evidence for high-risk items

## Usage
During ORIENT mode:
1. Estimate task size and clarity
2. Set lane accordingly
3. Use `maestro intake --paths <comma-separated-paths>` for data-driven lane setting
4. Follow lane-specific routing rules

## Lane Routing Rules

| Lane | Path | Skips |
|------|------|-------|
| **tiny** | ORIENT → (brief RESEARCH if unclear) → EXECUTE → REVIEW → SHIP | Full PLAN / Maestro mission when ask is unambiguous and blast radius ≤1 file/module |
| **normal** | Full pipeline; light Maestro task (`maestro_task_from_spec` or inline AC) | Heavy mission / multi-wave |
| **heavy** | Full pipeline + `/plan-hierarchically` + mission + execution overlay | Nothing — human approve before EXECUTE mandatory |

## How to set lane

1. During ORIENT, run `devenv shell -- maestro intake --paths <touched>` when paths known.
2. Else estimate: one-liner fix → `tiny`; single PR feature → `normal`; multi-PR / migrations / public API → `heavy`.
3. State `lane:<…>` every response. Upgrade lane if blast radius grows; never downgrade past human approval without saying so.

## tiny EXECUTE entry

Only enter EXECUTE from ORIENT/RESEARCH on `tiny` when:

- [ ] Sharp ask restated in one sentence
- [ ] Files to touch named
- [ ] No Maestro heavy mission required
- [ ] User did not demand a plan first