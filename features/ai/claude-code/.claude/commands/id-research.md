---
description: ID RESEARCH — evidence and competing hypotheses, read-only. No implementation.
argument-hint: "[question or phenomenon]"
---

[ID:RESEARCH]

Writes are blocked outside `.tmp/`. Notes go in `.tmp/`, never in the tree.

Read: `<id-pack>/modes/research.md`, then `PROTOCOL.md` rails 1–5.

## How to run it here

Recon through the MCP layer, not `cat`/`grep`: `ctx_compose` first to orient, then `ctx_read`
(`signatures`/`map` for context, `full` only for files you will edit), `ctx_search`, `roam_*` for
symbols and call graphs, `context7` for library docs, `searxng` for the open web.

Fan out **id-researcher** subagents in parallel when the question has separable strands — one per
subsystem, one per hypothesis. They are read-only, so parallelism here is free of write races. Give
each a narrow question and expect a short answer back, not a file dump.

Prefer the scientific method: observe → ranked hypotheses → cheapest disproof first.

## Produce

Phenomenon · baseline · constraints · named files · open questions. Dense bullets. No code.

Stay here as long as the user wants to debate (`/debate`). Advance with `/id-plan`, or `/id-execute`
on a `tiny` lane.

$ARGUMENTS

`<id-pack>` is `.cursor/commands/id-workflow/` in a project that has the shared pack, and `~/.claude/id-workflow/` otherwise — the payload carries a copy so the rails still resolve in a project with no `.cursor/` checkout.
