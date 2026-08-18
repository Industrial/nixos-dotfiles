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