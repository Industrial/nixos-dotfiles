---
description: ID PLAN — hierarchical Maestro-native plan, then stop for the human gate
argument-hint: "[what to plan]"
---

[ID:PLAN]

Writable now: `.maestro/**`, `.cursor/plans/**`, `.tmp/**`. Application source is blocked by
`guard-id-mode.sh` — that is rail 2, and it holds until the user approves.

Read: `<id-pack>/modes/plan.md`, `checklists/plan-exit.md`, and
`.cursor/commands/plan-hierarchically.md` — run its body, do not fork its content.

## How to run it here

Use the **id-architect** subagent for the plan body. Where the design space is genuinely open, run
two or three id-architect subagents on different framings in parallel and pick the winner on the
merits, grafting the best pieces of the runners-up — cheaper than iterating one plan five times.

Ground every leaf in real paths verified with `roam_*` / `ctx_search`. A plan citing a file that does
not exist is the failure mode this mode exists to prevent.

## Materialize per lane

| Lane | Artifact |
|---|---|
| tiny | inline AC, no Maestro task needed |
| normal | `.maestro/specs/<slug>.md` → `maestro task from-spec` |
| heavy | spec + mission + execution overlay |

Run `maestro plan check` once a task id exists.

## Exit — the human gate

- [ ] Plan grounded in real paths
- [ ] Leaves carry AC + gates
- [ ] Maestro artifacts exist (normal / heavy)
- [ ] Self-reviewed with `scrutinize`
- [ ] **User explicitly approved**

Present the plan and **stop**. Do not advance to `/id-execute` yourself unless the user asked for
plan-and-implement in one pass.

$ARGUMENTS

`<id-pack>` is `.cursor/commands/id-workflow/` in a project that has the shared pack, and `~/.claude/id-workflow/` otherwise — the payload carries a copy so the rails still resolve in a project with no `.cursor/` checkout.
