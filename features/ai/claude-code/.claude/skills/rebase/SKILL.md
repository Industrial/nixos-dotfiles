---
name: rebase
description: >-
  Rebases the current branch onto origin/<base> with conflict resolution,
  zdiff3 markers, and force-with-lease push. Use when syncing a feature or
  bugfix branch, updating before a PR, or when the user asks to rebase.
---

# Rebase

Linear history by replaying commits onto the latest base. Prefer this over merge for feature and bugfix branches.

For the full ship loop (branch → PR → CI), use the `pr-lifecycle` skill. For deep conflict resolution, use `merge-conflicts`.

## Workflow

```bash
git branch --show-current
git fetch origin
git rebase origin/<base>    # main or master
```

Announce how many commits will replay, then proceed unless the user said to stop.

## Before rebasing

- Commit or stash a dirty tree — rebase aborts on uncommitted changes
- Order: **commit → fetch → rebase → push**

## Conflict heuristics

| Situation | Resolution |
|-----------|------------|
| Lockfiles, migrations, version bumps | Prefer target branch (base) version, then regenerate lockfiles |
| Code refactored away on base | Base wins; rewire call sites to new API |
| Both sides add independent code | Keep both; run formatter/linter after each file |
| Same line changed incompatibly | Prefer feature-branch intent; note in commit message |

**Partial survival check:** If usage of a symbol survives, verify its declaration and import also survived.

## During rebase

For each conflicted file, see `merge-conflicts` skill. Minimal path:

```bash
git diff --name-only --diff-filter=U
# edit files — remove all <<<<<<< ||||||| ======= >>>>>>> markers
git add <resolved-files>
git rebase --continue
```

Abort if intent is incompatible: `git rebase --abort`

## After rebase

```bash
git push --force-with-lease
```

Rebase bypasses pre-commit hooks on replayed commits — run local verification (tests, lint) before pushing.

## Report

- Commits applied or dropped
- Conflicts resolved (file list)
- Push result

Adapted from [dotclaude](https://github.com/JHostalek/dotclaude) and [laurigates/claude-plugins](https://github.com/laurigates/claude-plugins).
