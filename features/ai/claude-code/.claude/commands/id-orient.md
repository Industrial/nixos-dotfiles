---
description: ID ORIENT — sharpen the ask, pick skills and role, set the lane. No writes.
argument-hint: "[the ask]"
---

[ID:ORIENT]

Mode is set in `.tmp/id/state.json`. Writes are blocked outside `.tmp/` until you advance —
that is `guard-id-mode.sh`, not a suggestion.

Read: `<id-pack>/modes/orient.md`, `lanes.md`, `checklists/orient-exit.md`.

Delegate the recon to the **id-researcher** subagent when the ask spans more than a couple of files —
it holds no write tools, so ORIENT stays honest by construction.

Exit checklist before advancing:

- [ ] Sharp ask restated in one sentence
- [ ] Skills reviewed vs using, listed
- [ ] Role chosen (researcher | architect | implementer | reviewer)
- [ ] `lane:` set with a reason
- [ ] `[ID:ORIENT]` declared this turn

Then `/id-research`, or `/id-execute` on a `tiny` lane with the files already named.

$ARGUMENTS

`<id-pack>` is `.cursor/commands/id-workflow/` in a project that has the shared pack, and `~/.claude/id-workflow/` otherwise — the payload carries a copy so the rails still resolve in a project with no `.cursor/` checkout.
