---
name: id-execute
description: >
  ID EXECUTE mode: Implement contract-scoped code only. Use when building 
  according to approved Maestro plan.
tags: [id-workflow, execution, implementation, coding]
---

# ID EXECUTE Mode

## Goal
Implement contract-scoped code according to approved Maestro plan.

## Activities
- Claim Maestro tasks: `maestro task claim <id> --skip-worktree`
- Implement only what's in the task contract
- Record evidence after each quality gate (bind each contract `doneWhen dw-*`
  id via `evidence record --criterion <id>`; mission-wide ACs land on the leaf
  that proves them). Plain evidence rows sit below the high-risk witness bar:
  `verdict request` prints Decision: HUMAN regardless — the gate that unlocks
  shipping is `maestro task verify <id> --json` → `"verdict":"PASS"`.
- Session-proven CLI mechanics (plan-check wants a machine-readable
  `<slug>.plan-check.yaml`, NOT the human `.plan.md`; contracts/dw-ids exist
  only post-claim): `references/maestro-cli-loop.md` under plan-hierarchically.
- Ship completed work: `maestro task ship`

## Writes Allowed
- Contract-scoped code changes only
- No modifications outside EXECUTE/SHIP modes
- All changes must be within task boundaries defined in Maestro contract

## Exit Criteria
For each leaf task:
- Task is done (implementation complete)
- Evidence recorded for all quality gates
- Maestro verdict shows PASS
- Task is shipped: `maestro task ship <id>`

When all tasks in current wave are shipped, advance to REVIEW.

## Concurrent-agent discipline (shared working tree)

When another agent commits into the same repo while you execute:

1. **HEAD moves under you.** Re-run `git log --oneline -3` + `git status`
   immediately before every commit; never assume your session-start snapshot.
2. **Classify shared-file hunks before staging.** For every file both of you
   touched (`git diff <shared-file>`), decide mine/foreign per hunk. If their
   commit sweeps your staged hunks first (it happens), verify the swept
   content is equivalent (`git show HEAD:<file>`) and shrink your remaining
   path list instead of re-staging.
3. **Commit by explicit path list only** (`git commit -m ... -- <paths>`),
   never `git add -A`. Argument order matters: `-m` must precede `--`, or
   git parses the message as pathspecs.
4. **Foreign WIP breaks collection.** If the other agent's syntax-broken WIP
   file makes full-suite collection ERROR, run your scoped gate with
   `--ignore=<their test file>` and report the exclusion as foreign — do not
   fix or touch their files.
5. **Unique temp names for gate output.** Redirect pytest/ruff output INSIDE
   devenv commands to a file, and make it unique per run
   (`OUT=/tmp/gate_$$_<task>.txt`). A parallel agent overwrote a shared
   `/tmp/w1gate.txt` mid-session and nearly produced a false green verdict.
6. **Baseline is a snapshot, not a fact.** Capture Wave-0 failing test IDs,
   but expect baseline reds to disappear/appear as the other agent lands;
   compare against the CURRENT HEAD, not your morning notes.
7. **Prune the index before pathspec commits.** A prior blocked hook run or
   foreign staging leaves unrelated entries in the index; they ride into your
   commit unless you `git restore --staged <foreign-paths>` first, then verify
   with `git diff --cached --stat` that ONLY your paths remain.
8. **Untracked dirs need explicit `git add`.** `git commit -m msg --
   <untracked/path>` fails ("pathspec did not match") because commit takes
   working-tree content of TRACKED paths only — add your new package/files
   yourself, then prune anything else that staged along.
9. **Hook stash/rollback can eat your edits.** The prek hook stashes working-
   tree changes, runs gates, and restores; when it blocks mid-run it can
   silently revert YOUR uncommitted edits made between attempts (a landed
   ARCHITECTURE.md table vanished this way). After every blocked commit:
   `git status` on your touched files + re-grep your last edit; re-apply and
   re-commit if gone.