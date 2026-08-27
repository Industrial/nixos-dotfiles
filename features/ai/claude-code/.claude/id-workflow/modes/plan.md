# Mode: PLAN

`[ID:PLAN]`

## Goal

Hierarchical, Maestro-native plan; human approval before EXECUTE.

## Steps

1. Load and follow `.cursor/commands/plan-hierarchically.md` (do not fork its content).
2. Materialize Maestro artifacts per lane ([lanes.md](../lanes.md)).
3. Self-review with `engineering/scrutinize`.
4. Present plan; **stop** for approval unless user asked plan+implement.

## Writes

Allowed: `.maestro/**`, `.cursor/plans/**`, specs referenced by Maestro.  
Forbidden: application/source edits.

## Exit

[plan-exit.md](../checklists/plan-exit.md) + explicit user approve → EXECUTE.
