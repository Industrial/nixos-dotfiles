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
- Push to remote: `git push`
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