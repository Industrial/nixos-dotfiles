---
name: merge-conflicts
description: >-
  Resolves merge and rebase conflicts file-by-file using zdiff3 markers,
  rerere, and file-type strategies. Use when a merge or rebase has conflicts,
  a PR cannot merge, or the user asks to fix conflicts.
---

# Merge Conflicts

Resolve conflicts during merge, rebase, or cherry-pick. Works with `gh` when a PR is blocked on mergeability.

## When to use

| Use this skill | Escalate to user instead |
|----------------|--------------------------|
| Merge/rebase produced conflicts | Architectural redesign across many files |
| PR shows conflicts / not mergeable | Business logic requires product decision |
| Config or lockfile divergence | Only lockfiles conflict — regenerate after resolving deps |
| Accept one side wholesale (`--ours` / `--theirs`) | Same conflicts recur from squash-merge chains |

## Assess

```bash
git branch --show-current
git status --porcelain=v2 --branch
test -f .git/MERGE_HEAD && echo merge || test -d .git/rebase-merge && echo rebase
git diff --name-only --diff-filter=U
git config --get merge.conflictStyle
git config --get rerere.enabled
```

**PR blocked but no local merge state:**

```bash
gh pr view --json headRefName,baseRefName,mergeable
git fetch origin
git rebase origin/<base>    # prefer rebase; see rebase skill
```

## Enable zdiff3 (recommended)

Three-way markers with common ancestor are easier to read than two-way:

```bash
git config merge.conflictStyle zdiff3
git config rerere.enabled true
git config rerere.autoupdate true
git checkout --conflict=zdiff3 -- <file>   # per conflicted file
```

Marker shape:

```
<<<<<<< HEAD
(current branch)
||||||| merged common ancestors
(ancestor)
=======
(incoming)
>>>>>>> branch-name
```

## Resolve

**Accept all ours:**

```bash
git restore --ours -- <file> && git add <file>
```

**Accept all theirs:**

```bash
git restore --theirs -- <file> && git add <file>
```

**Rebase ours/theirs swap:** During rebase, `--ours` = base branch, `--theirs` = your commits.

**Intelligent merge by file type:**

| File type | Strategy |
|-----------|----------|
| `package.json`, manifests | Merge keys; take higher versions |
| YAML config | Merge keys from both sides |
| `CHANGELOG.md` | Both entries, chronological order |
| Docs / README | Include both sides |
| Source code | Integrate both intents; use `\|\|\|\|\|\|\|` section |
| Lock files | Resolve deps first, delete lockfile, regenerate |
| `.release-please-manifest.json` | Take higher version numbers |

After editing: remove **all** markers, `git add <file>`.

## Complete

```bash
grep -rn '<<<<<<<' .    # must find nothing staged
git diff --name-only --diff-filter=U   # must be empty
git rerere status
```

Then:

- Merge: `git commit --no-edit`
- Rebase: `git rebase --continue`
- Push: `git push --force-with-lease` (after rebase) or `git push`

## Abort

```bash
git merge --abort
git rebase --abort
```

Abort when conflicts need requirements you cannot infer, or span incompatible architecture.

## Squash-merge pitfall

Recurring conflicts on stacked branches often come from squash merges breaking ancestry. Fix: rebase dependents with `git rebase --onto origin/<base> <old-base> <branch>`. Rerere replays prior resolutions.

## Pre-merge trial (parallel PR waves)

Validate conflict resolution before touching main:

```bash
git switch -c trial/integration origin/<base>
for b in branch-1 branch-2 branch-3; do
  git merge --no-ff --no-edit "origin/$b" || git commit --no-edit
done
<project test command>
git switch <base> && git branch -D trial/integration
```

Rerere caches resolutions for the real merges.

## Quick reference

| Task | Command |
|------|---------|
| List conflicts | `git diff --name-only --diff-filter=U` |
| zdiff3 checkout | `git checkout --conflict=zdiff3 -- <file>` |
| Recreate markers | `git checkout -m -- <file>` |
| PR mergeable | `gh pr view --json mergeable` |
| Continue rebase | `git rebase --continue` |

Adapted from [laurigates/claude-plugins](https://github.com/laurigates/claude-plugins) git-conflicts skill.
