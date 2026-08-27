---
name: id-workflow
description: >
  Industrial Delivery (ID) workflow - mode-gated agent pipeline using Maestro as tracker.
  Use for structured project execution with ORIENT→RESEARCH→PLAN→EXECUTE→REVIEW→SHIP modes.
  Requires declaring [ID:<MODE>] and lane:<tiny|normal|heavy> in every response.
tags: [workflow, maestro, industrial-delivery, process]
---

# Industrial Delivery (ID) Workflow

## Mode Machine
```
ORIENT → RESEARCH → PLAN → EXECUTE → REVIEW → SHIP
         ↑______________|         ↑____FAIL____|
```

### Mode Definitions & Writes Allowed

| Mode | Writes Allowed | Advance When |
|------|----------------|--------------|
| **ORIENT** | none | Ask sharp; skills+agent listed; lane set |
| **RESEARCH** | none | Enough context to plan (or debate-only loop) |
| **PLAN** | Maestro/spec/plan artifacts only | Human approves plan |
| **EXECUTE** | contract-scoped code | Leaf done + evidence recorded |
| **REVIEW** | evidence notes only | Verdict PASS → SHIP; FAIL → EXECUTE |
| **SHIP** | git/gh only | Pushed / session-close complete |

## Hard Rails (Protocol Rules)

1. **Declare mode every response:** first line `[ID:<MODE>]` then `lane:<tiny|normal|heavy>`
2. **Write ban:** no code/config edits outside EXECUTE/SHIP. PLAN may write `.maestro/**`, `.cursor/plans/**`, specs only.
3. **Human gate:** do not enter EXECUTE until the user explicitly approves the plan.
4. **Exit criteria:** satisfy mode checklist before advancing.
5. **Quality floor:** correctness > brevity. Sharpen the ask.
6. **No parallel trackers:** no BMAD stories, RIPER memory-bank, or markdown TODO files — Maestro `tsk-`/`pln-` only.
7. **Compose, do not duplicate:** PLAN delegates to planning skills; EXECUTE to Maestro claim→verify→ship.
8. **No Maestro worktrees:** claim with CLI `--skip-worktree` only.

## SHIP Pitfalls

### Always-run pre-commit gates (moon / prek / devenv repos)
Repos generated from git-hooks.nix install prek hooks whose config sets
`always_run: true` — EVERY commit runs the full moon test+coverage gate
regardless of what is staged. If the repo gate is red, all commits block,
including docs-only ones.

1. Blocked? Prove the failures are PRE-EXISTING and ORTHOGONAL before doing
   anything else: reproduce the failing tests directly on HEAD and note the
   diff is docs/config-only.
2. Then commit with `git commit --no-verify` and record the evidence (failing
   test names, root-cause line, coverage number vs floor) in the commit
   message body so history explains why verification was skipped.
3. A BLOCKED hook run may still have mutated the working tree — formatters
   execute before the failing stage. After any failed commit attempt, run
   `git status`; revert collateral (formatter rewraps, JSON key reordering)
   with `git checkout -- <paths>`. File mtimes matching the commit-attempt
   time confirm origin.
4. Never silently skip verification: report the broken gate as follow-up work.

### Proving pre-existing gate failures (deadlock escape)

1. Blocked? First prove attribution on PRISTINE HEAD: `git worktree add /tmp/head-proof
   <HEAD-sha>`, then run ONLY the failing tests there. Failures that reproduce there
   are pre-existing; ones that pass there belong to uncommitted working-tree state —
   yours or another agent's WIP.
2. Shared checkout with a concurrent second agent: never `git add -A`; re-check
   `git log --oneline -3` immediately before every commit (HEAD moves); expect foreign
   uncommitted WIP to keep tree-wide runs red. Scope verification to your own change
   surface (`pytest <your-paths> -k 'not their_feature'`) and say so explicitly rather
   than repairing their in-flight files. THE INDEX IS ALSO SHARED STATE: entries another
   agent staged ride into your commit even when you pass explicit paths (real cases:
   a foreign `runner_container.py` deletion; foreign CandleService hunks inside three
   shared files of an otherwise-clean service-extraction commit). Run
   `git diff --cached --stat` right before committing and confirm EVERY listed path
   is yours. Preferred remedy is a PATHSPEC-LIMITED commit
   (`git commit -m ... -- <your paths>`), which takes only named paths and leaves
   unrelated staged entries staged; reach for `git restore --staged <foreign-path>`
   only when you can see the other agent is idle, because unstaging mid-flight can
   corrupt their in-flight operation.
3. A blocked hook run can still mutate STAGED files (formatters execute before the
   failing stage). Inspect the diff on staged paths and re-`git add` your own
   reformatted files before the bypass attempt.
4. After EVERY commit on the shared tree, run `git show --stat HEAD` and read every
   listed path: broad-path staging sweeps in foreign staged entries (real case:
   another session's `services/venue_service{,_test}.py` rode along inside an
   explicit-path commit because it was already staged). Accept harmless riders but
   disclose them; if a rider breaks the build, fix forward in your own follow-up.
5. When `SKIP=<hook>` env vars don't reach nested runners (moon/prek spawn their own
   git), commit ONCE with `git -c core.hooksPath=/dev/null commit` after step 1, and
   put the evidence in the message body: failing test names, root-cause line, HEAD sha
   where reproduction succeeded.

### Human gate in practice

Approval is PER PLAN, judged by the plan text actually put in front of the
user this session. A blanket "execute all waves" in the original request covers
that request's plan; a NEW plan produced later (new target, redesigned area)
needs its own explicit approval — offer it as a clear choice and if the user
says "show me the plan first / let's discuss", STOP in PLAN mode: print the
full plan in-chat (tables, waves, open decision points), invite edits, and do
not start EXECUTE until they approve the printed artifact. Do not fold
approval into an execute-immediately option without the plan being visible.

### Concurrent-execution collision (another session executes your plan)

Signal: `git mv` dies with `bad source` on paths verified minutes ago; tree diverges from
recon. NEVER retry the move — re-check state immediately (`git log --oneline -2`,
`git status --porcelain`, `ls`). Real case: contexts/execution dissolved by a parallel
session between this session's plan approval and wave-1 dispatch.

Protocol when a parallel session executed your planned work while you were starting:
1. Attribute: did HEAD advance? Committed or staged (`git diff --cached --stat`)?
   Unstaged edits on top of staged moves = they are STILL mid-flight.
2. Never touch their staged/unstaged state — no restores, no competing edits, even where
   scopes overlap yours. Their remap/`_CANON` additions may encode facts your plan missed
   (real case: their pickle remap proved a class WAS pickled where your plan claimed none).
3. Convert to read-only verification of THEIR in-flight state: import-residual greps,
   F821 over the affected surface, scoped pytest battery, logger/patch-string spot checks;
   attribute every failure (foreign file vs real defect vs scratch-env gap like a bare
   `.venv` missing deps) before reporting.
4. Annotate YOUR plan artifact with an "Outcome annotation" section: who executed it,
   deltas vs your placement table/user rulings (including where they went further than
   your REC), and residual gaps left for their closeout. Cancel your wave todos
   (status=cancelled, not completed).
5. Update the memory area-ledger entry so future sessions know the new layout.

Foreign staged COSMETIC hunks on your own surface (isort/format normalization riding in
their sweep): pure-format diffs ride along as disclosed riders — unstaging mid-flight
risks corrupting their operation (same doctrine as index contamination below). Distinguish
via `git diff --cached -- <path>`: reorder-only hunks = cosmetic; semantic hunks = escalate.

### Tracker-unavailable fallback

Worked examples for shared-checkout EXECUTE: index contamination catches,
bounded-splice edits, patch false-positives + partially-applied batch ops,
post-revert cache staleness, kwarg sweeps, facade absorption (free functions →
service methods without import cycles), four-shape test-cutover sweeps, and
duplicate near-name module disambiguation:
`references/live-shared-checkout-execution.md`.

Missing Maestro CLI/MCP is a deviation, not a blocker: write the plan artifact to a
PLAN-allowed location (e.g. `.cursor/plans/**`), track waves with the session todo
list, keep commits wave-sized, and state the deviation once in the plan plus each
commit body so REVIEW/SHIP retain an audit trail.

Same doctrine for BROKEN GATE TOOLS: a mandatory gate command failing for EVERY
input is a tool bug, not an artifact bug (real case: `maestro plan check`
rejecting ALL `.cursor/plans/*.plan.md` files — whole-file YAML multi-document
error at the frontmatter `---` close, repo-wide). Do NOT loop reformatting your
artifacts to appease the parser. Escape: (1) prove pre-existing + orthogonal by
running the gate once on a sibling mission's untouched plan file; (2) substitute
manual verification against the mode checklist; (3) record the substitution once
as a deviation in the execution overlay / commit trail so REVIEW sees why gate
output is absent.

### devenv-wrapped commands
All commands go through `devenv shell -- …`, which emits workspace-sync noise
around real output. Use raw output mode and filter when reading results, but
prefer this robust pattern for anything whose output you need verbatim: run
`bash -c "<cmd> > /tmp/out.log 2>&1; echo exit=\$?; tail -N /tmp/out.log"` —
pipes/grep chains after devenv get swallowed by sync/hook noise, while the
temp-file + exit-code pattern always survives. Prefer re-reading the /tmp file
over lean-ctx firewalled-archive expansion for multi-part results: archives
expire between turns and truncate long output at the head. Long gates (>110s
foreground cap) auto-detach to background jobs — poll status instead of
re-running.

### Edit-tool discipline inside EXECUTE

Batch same-file edits as ONE ctx_patch `ops[]` call, but know its failure
semantics: one bad op (typo'd path, stale anchor) rejects the WHOLE batch
atomically, yet a transport-level error ("server unreachable") can mask ops
that DID apply — grep/read the region after ANY batch error before re-sending,
never assume nothing landed. And drive one file through one tool family per
wave: mixing native patch with ctx_patch on the same file invites inverted/
stale anchors and silent drift that only post-edit verification catches.

### Mode → Agent Mapping

| Mode | Default Agent Rule |
|------|-------------------|
| ORIENT / RESEARCH | `agent-researcher` |
| PLAN | `agent-architect` |
| EXECUTE | `agent-implementer` |
| REVIEW / SHIP | `agent-reviewer` |

## Lane System
See `lanes.md` skill for lane routing rules:
- `tiny` + clear → brief RESEARCH or EXECUTE if files known
- otherwise → RESEARCH
- `normal`/`heavy` → RESEARCH → PLAN → wait for approve → EXECUTE → REVIEW → SHIP

## Usage
This skill provides the ID workflow framework. Agent behaviors are implemented through:
- Maestro for task tracking and execution
- Planning skills for specification creation
- Execution skills for implementation
- Review skills for verification

When this skill is active, you should:
1. Start every response with `[ID:<MODE>]` followed by `lane:<tiny|normal|heavy>`
2. Follow the mode-specific guidelines from the subordinate skills
3. Only write to allowed locations for the current mode
4. Advance modes only when exit criteria are met
5. Use Maestro CLI for task management when in EXECUTE mode