---
description: ID REVIEW — falsify the diff against the plan with a parallel lens panel, then verdict
argument-hint: "[tsk-id, or blank for the working diff]"
---

[ID:REVIEW]

Writable: `.maestro/**` and `.tmp/**` only. Fixing what you find is EXECUTE work — go back through
`/id-execute` rather than patching from here. The guard will hold you to it.

Read: `<id-pack>/modes/review.md`, `checklists/review-exit.md`.

## The lens panel

Dispatch four **id-review-lens** subagents **in parallel, in one message**. They run on Haiku and are
read-only, so a four-way panel costs less than one careful pass by this session and catches more,
because each lens is blind to what the others are excusing:

| Lens | Question it must answer |
|---|---|
| `ac` | Does the diff satisfy every acceptance criterion in the Maestro contract, literally? |
| `correctness` | Where does this break — edge cases, error paths, concurrency, nulls? |
| `scope` | What changed that the contract did not authorize? Drive-by edits, widened scope, dead code left behind |
| `tests` | What behaviour introduced here has no test, and which existing test would not fail if the change were reverted? |

Give each lens the contract AC and the diff range. Ask for findings with file:line and a concrete
failure scenario — not impressions.

Then **you** adjudicate. A lens finding is a hypothesis; confirm it against the code before it goes
in the verdict. Cheap models over-report; the merge step is where that gets filtered, and a confirmed
finding needs a reproduction, not a citation.

## Gates and verdict

```
bun run ci:pre-push          # or the narrower gate the contract names
```

Record with `maestro_evidence_record`, then `maestro_verdict_request`.

## Exit

- [ ] AC checked against the diff, one by one
- [ ] Deviations flagged, or explicitly none
- [ ] Gates run, evidence recorded
- [ ] Verdict recorded

PASS → `/id-ship`. FAIL → `/id-execute` with a concrete fix list.

$ARGUMENTS

`<id-pack>` is `.cursor/commands/id-workflow/` in a project that has the shared pack, and `~/.claude/id-workflow/` otherwise — the payload carries a copy so the rails still resolve in a project with no `.cursor/` checkout.
