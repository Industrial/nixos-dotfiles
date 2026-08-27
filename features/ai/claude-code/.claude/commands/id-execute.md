---
description: ID EXECUTE — implement one approved leaf inside the Maestro contract
argument-hint: "[tsk-id or what to build]"
---

[ID:EXECUTE]

The write ban is lifted. Everything else tightens.

Read: `<id-pack>/modes/execute.md`, then `maestro_contract_show` for the claimed
task.

## Before the first edit

1. Confirm the human gate was passed — approval, or an explicit plan-and-implement.
2. Claim on the **current branch**, never through MCP (`maestro_task_claim` silently creates a
   heavy-mode worktree and has no skip flag):
   ```
   devenv shell -- maestro task claim <tsk-id> --agent <agent-id> --skip-worktree --tool claude-code
   ```
3. Record the task id in the mode state so the statusline and any resumed session carry it:
   ```
   bash plugins/id-workflow/hooks/id-state.sh set EXECUTE --task <tsk-id>
   ```
4. `maestro_contract_show` — stay inside the contracted paths. If scope genuinely grows, amend the
   contract; do not widen silently.

## While implementing

Use the **id-implementer** subagent for self-contained leaves. Stay on the checked-out branch — never
`cd` into `.maestro/worktrees/` or a sibling `*-tsk-*` tree.

No drive-by refactors. The diff should read as one intention.

Gates for this repo:

| What | Command |
|---|---|
| format | `bun run format` |
| lint + types | `bun run oxlint && bun run typecheck` |
| tests | `moon run :test` (affected: `bun run ci:pre-commit`) |
| full pre-push | `bun run ci:pre-push` |

Record evidence after each gate (`maestro_evidence_record`).

## Exit

Leaf AC met and evidence recorded → `/id-review`.

$ARGUMENTS

`<id-pack>` is `.cursor/commands/id-workflow/` in a project that has the shared pack, and `~/.claude/id-workflow/` otherwise — the payload carries a copy so the rails still resolve in a project with no `.cursor/` checkout.
