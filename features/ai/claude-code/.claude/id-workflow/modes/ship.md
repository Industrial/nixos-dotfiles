# Mode: SHIP

`[ID:SHIP]`

## Goal

Land the work: verify → ship task → push/PR as required.

## Steps

1. `maestro_task_ship` when verdict PASS / ready.
2. Commit per user rules; push when session-close or user asked.
3. Prefer `devenv shell -- definitively run .definitively/programs/session-close.yml` or `/pre-push` parity.
4. Handoff envelope if work continues elsewhere.

## Writes

git / gh only (plus Maestro state transitions).

## Exit

[ship-exit.md](../checklists/ship-exit.md).
