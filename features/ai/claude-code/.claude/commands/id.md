---
description: Industrial Delivery orchestrator — enter ORIENT and auto-route through the mode machine
argument-hint: "[what you want done]"
---

# /id — Industrial Delivery

Entering **ORIENT**. `plugins/id-workflow/hooks/id-mode-from-prompt.sh` has already written the mode to
`.tmp/id/state.json`; the statusline should read `[ID:ORIENT]`. If it does not, run
`bash plugins/id-workflow/hooks/id-state.sh set ORIENT` through `ctx_shell` (native Bash is blocked here).

## Load the rails

The canonical pack lives at `<id-pack>/` and is shared with Cursor and Hermes —
read it, never fork it:

1. `<id-pack>/PROTOCOL.md` — hard rails and the mode machine
2. `<id-pack>/modes/orient.md` — this mode's playbook
3. `<id-pack>/lanes.md` — how to pick tiny / normal / heavy
4. `<id-pack>/checklists/orient-exit.md` — what must be true to leave

## What Claude Code enforces for you

| Rail | Mechanism |
|---|---|
| Write ban per mode | `plugins/id-workflow/hooks/guard-id-mode.sh` denies the write; you cannot forget |
| Mode is a fact, not a memory | `.tmp/id/state.json`, shown in the statusline, restored after compaction |
| Role separation | `plugins/id-workflow/agents/id-*.md` — researcher and reviewer hold no write tools at all |

So do not spend turns promising not to edit. Spend them on the work; the guard will stop you if the
mode is wrong, and the deny message names the mode to advance to.

## Route

- Declare `[ID:ORIENT]` then `lane:<tiny|normal|heavy>` as the first line of your reply.
- Restate the ask in its sharpest correct form. Name the files in play.
- Set the lane — `devenv shell -- maestro intake --paths <touched>` when paths are known, otherwise
  estimate per `lanes.md`.
- Then advance: `tiny` and unambiguous → `/id-execute`; anything else → `/id-research`.

## Task

$ARGUMENTS

`<id-pack>` is `.cursor/commands/id-workflow/` in a project that has the shared pack, and `~/.claude/id-workflow/` otherwise — the payload carries a copy so the rails still resolve in a project with no `.cursor/` checkout.
