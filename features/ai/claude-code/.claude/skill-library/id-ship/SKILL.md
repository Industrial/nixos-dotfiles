---
name: id-ship
description: >
  ID SHIP mode: Git/GitHub operations only. Use when releasing completed work.
tags: [id-workflow, shipping, release, git]
---

# ID SHIP Mode

## Goal
Complete git/GitHub operations to release work.

## Activities
- Pull latest changes: `git pull --rebase`
- Handle divergent branches after rebasing: if `git push` fails with "non-fast-forward", use `git pull --rebase origin <branch-name>` to integrate remote changes
- When updating feature branches from main:
  1. Checkout the feature branch: `git checkout feature-branch`
  2. Rebase onto latest main: `git rebase main`
  3. Push with force-lease (required after rebasing): `git push --force-with-lease origin feature-branch`
- When rebasing a branch with local changes:
  1. Stash local changes: `git stash push -m "descriptive message"`
  2. Perform rebase operations
  3. Pop stash: `git stash pop`
  4. If conflicts occur after popping stash, resolve them and continue
  5. After restoring stashed changes, if remote branch has diverged, reconcile with `git pull --rebase origin <branch-name>`
- Commit changes incrementally: make small, logical commits from unstaged changes (group related files, stage each group, commit with concise message)
- Push to remote: `git push` (use `--force-with-lease` if you've rebased)
- Verify status: `git status` (must show "up to date with origin")
- Clean up: clear stashes, prune remote branches
- Final verification: all changes committed and pushed

## Writes Allowed
- Git operations only (commit, push, etc.)
- No code changes outside of git operations

## Exit Criteria
- All changes are committed AND pushed to origin
- `git status` shows clean working tree
- Branch is up to date with origin remote
- No outstanding stashes or uncommitted work

Workflow is complete when SHIP mode exit criteria are met.

## Always-run hook gates (prek / moon repos)

Repos generated from git-hooks.nix install prek hooks whose config sets
`always_run: true`: EVERY commit runs the full moon test+coverage gate
regardless of what is staged. When the gate blocks on failures that are
PRE-EXISTING or FOREIGN (another agent's WIP):

1. Prove it first: reproduce the failing tests standalone at pure HEAD.
   A linked worktree (`git worktree add --detach /tmp/<unique>-proof HEAD`)
   does NOT evaluate the flake — run its tests with the main checkout's
   venv python (`.devenv/state/venv/bin/python -m pytest ...`) instead of
   devenv shell.
2. Then a SINGLE bypassed commit: `git -c core.hooksPath=/dev/null commit ...`
   with the evidence (failing test IDs, why foreign/pre-existing, gate name)
   recorded in the commit message body. Never silently skip; report the
   broken gate as follow-up.
3. After any blocked attempt, check `git status` — formatter stages may have
   mutated the tree mid-gate; revert collateral before retrying.

## Partial commits in shared trees

To commit only your paths while another agent holds staged entries:

```
git restore --staged <foreign-paths>     # prune foreign entries FIRST
git add <your-new-untracked-dir/files>   # untracked paths MUST be added
git diff --cached --stat                 # confirm ONLY your paths remain
git commit -m "<message>" -- <explicit/path>...
```

Takes the working-tree content of just those paths and ignores foreign
staged entries. Pitfalls:
- `-m` MUST come before `--` (reversed, git treats the message as pathspecs).
- `git commit ... -- <path>` fails outright ("pathspec did not match") for
  UNTRACKED paths — brand-new packages/dirs must be `git add`ed first, and
  that add may sweep in neighbors (questdb artifacts, foreign staged files),
  so re-run `git diff --cached --stat` and prune before committing.
- Verify beforehand that uncommitted deltas on your shared files contain no
  foreign hunks (`git diff <file>` + `git diff --cached --stat -- <paths>`).
- The prek hook stashes working-tree changes and restores them after the gate;
  a blocked run can silently REVERT your own uncommitted edits made between
  attempts. After any blocked commit, re-grep your last edit (an ARCHITECTURE.md
  table vanished this way) and re-apply before the next attempt.

## Concurrent-agent sweep recovery

If another agent's landed commit contains hunks of yours (they stage
shared files too): verify content equivalence via `git show HEAD:<file>`,
remove those paths from your commit list, and note the overlap in your
commit message. Do not re-commit identical content.