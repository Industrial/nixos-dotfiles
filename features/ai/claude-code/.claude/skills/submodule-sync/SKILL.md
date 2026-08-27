---
name: submodule-sync
description: >-
  Keeps all git submodules current: pull --rebase in each submodule, resolve
  rebase conflicts, commit and push submodule changes, then bump submodule
  pointers in the parent repo and sync the parent the same way. Use when
  updating submodules, syncing .cursor or other nested repos, or when the user
  asks to pull/rebase/push submodules.
---

# Submodule Sync

Keep every submodule and the parent repo aligned with their remotes using **rebase-first** linear history. Run this end-to-end — do not stop after pulling one submodule.

For conflict resolution see `merge-conflicts`. For rebase mechanics see `rebase`. For commit messages see `writing-commit-messages`.

## When to use

| Use this skill | Escalate to user instead |
|----------------|--------------------------|
| User asks to update/sync submodules | Submodule URL or branch must change |
| `.cursor` or other submodule is stale | Submodule has unpushed commits you did not author |
| Parent shows `M` or `M?` on submodule path | Parent has unrelated WIP you must not touch |
| After adding files inside a submodule | Nested submodule needs new `.gitmodules` entry |

## Discovery

```bash
git submodule status --recursive
cat .gitmodules
git status -sb
```

Build an ordered list: **deepest submodules first**, parent repo last.

## Per-submodule loop

For each submodule path `$SUB` (deepest → shallow):

### 1. Enter and assess

```bash
cd "$SUB"
git status -sb
git branch --show-current
git remote -v
```

### 2. Commit local work before sync

If the submodule has changes belonging to this task:

```bash
git add <paths>
git commit -m "$(cat <<'MSG'
<type>(<scope>): <subject>

<body if needed>
MSG
)"
```

Stash unrelated WIP only when the user asked to sync without committing it:

```bash
git stash push -u -m "submodule-sync: pre-rebase stash"
```

### 3. Pull with rebase

```bash
git fetch origin
git pull --rebase origin "$(git branch --show-current)"
```

If `pull --rebase` fails because of uncommitted changes, commit or stash first — never `--autostash` without reporting it.

### 4. Resolve rebase conflicts

```bash
git diff --name-only --diff-filter=U
# resolve each file — remove all conflict markers
git add <resolved-files>
git rebase --continue
```

Repeat until rebase completes. Abort only when intent is incompatible:

```bash
git rebase --abort
```

Apply `merge-conflicts` heuristics. During submodule rebase, `--ours` is upstream (remote), `--theirs` is local replayed commits.

### 5. Push submodule

```bash
git push origin HEAD
```

If the branch was rebased and already had a remote tracking branch:

```bash
git push --force-with-lease
```

Return to repo root: `cd -` or `cd "$(git rev-parse --show-toplevel)"`.

## Parent repo: bump pointers

After every submodule in the wave is pushed:

```bash
git submodule status --recursive
git add .gitmodules <submodule-paths-with-new-SHAs>
git status
```

Commit pointer updates separately from unrelated parent work when possible:

```bash
git commit -m "$(cat <<'MSG'
chore(submodules): bump <name> to <short-sha>

Sync submodule after pull --rebase and push.
MSG
)"
```

## Parent repo: sync self

Same rebase-first loop on the parent:

```bash
git fetch origin
git pull --rebase origin "$(git branch --show-current)"
# resolve conflicts if any — submodule pointer conflicts: take the SHA you just pushed
git push origin HEAD
# or --force-with-lease after rebase
```

### Submodule pointer conflicts during parent rebase

When conflict markers appear in the parent diff for a submodule entry:

1. Confirm the intended SHA: `cd <submodule> && git rev-parse HEAD`
2. Stage the correct gitlink: `git add <submodule-path>`
3. `git rebase --continue`

Never hand-edit gitlink SHAs without verifying inside the submodule.

## Recursive submodules

When `.gitmodules` nests submodules:

```bash
git submodule update --init --recursive
git submodule foreach --recursive 'git fetch origin'
```

Still process **deepest first** for pull/commit/push; run `submodule update` after parent pointer commits.

## Checklist

```
Submodule sync:
- [ ] Listed all submodules (--recursive)
- [ ] Deepest → shallow order
- [ ] Each submodule: committed local work (or stashed with report)
- [ ] Each submodule: pull --rebase
- [ ] Rebase conflicts resolved (merge-conflicts skill)
- [ ] Each submodule: pushed
- [ ] Parent: git add submodule paths + .gitmodules
- [ ] Parent: committed pointer bump
- [ ] Parent: pull --rebase + push
- [ ] Final: git submodule status --recursive clean vs intent
```

## Report

For each submodule:

- Path, branch, before/after SHA
- Pull result (already up to date / rebased N commits)
- Conflicts resolved (file list) or none
- Push result

For parent:

- Pointer commit SHA
- Pull/push result

## Anti-patterns

- `git pull` without `--rebase` on submodules or parent
- Updating parent pointer before submodule push succeeds
- `git submodule update --remote` without reviewing submodule commits
- Force-pushing submodules shared by others without `--force-with-lease`
- Mixing unrelated parent changes into the submodule bump commit
- Skipping nested submodules when `--recursive` shows more than one level

## Quick reference

| Task | Command |
|------|---------|
| List submodules | `git submodule status --recursive` |
| Pull rebase in submodule | `git pull --rebase origin $(git branch --show-current)` |
| Conflicts | `git diff --name-only --diff-filter=U` |
| Continue rebase | `git rebase --continue` |
| Push after rebase | `git push --force-with-lease` |
| Bump pointer | `git add <path> && git commit` |
| Init missing | `git submodule update --init --recursive` |
