---
name: pr-lifecycle
description: >-
  Creates feature/* or bugfix/* branches, rebases onto the latest base branch,
  opens GitHub pull requests with gh, watches CI to completion, and fixes
  failures in a commit-push-retry loop. Use when shipping work, opening a PR,
  pushing a feature branch, syncing with main, or when the user asks to create
  a branch, open a PR, or get CI green. For rebase-only tasks, prefer the `rebase` skill.
---

# PR Lifecycle

End-to-end workflow: branch → rebase onto base → push → PR → watch CI → fix failures → repeat until green.


Related skills in `skills/git/`:
- `writing-commit-messages` — conventional commit format and commitizen hooks
- `rebase` — detailed rebase and conflict heuristics
- `merge-conflicts` — file-by-file conflict resolution (zdiff3, rerere)

Use `gh` for all GitHub operations. Never update git config. Do not force-push unless the user explicitly asks, except `--force-with-lease` after a rebase (see step 2).

## Quick checklist

```
- [ ] 1. Ensure on feature/* or bugfix/* branch
- [ ] 2. Rebase onto latest origin/<base>
- [ ] 3. Commit and push work
- [ ] 4. Open PR if none exists
- [ ] 5. Watch CI until pass or fail
- [ ] 6. On fail: diagnose → fix → rebase if behind → commit → push → return to 5
- [ ] 7. Report PR URL and final CI status
```

## 1. Branch setup

Get current branch and base branch:

```bash
git branch --show-current
git remote show origin | sed -n '/HEAD branch/s/.*: //p'   # usually main or master
```

**Already on `feature/*` or `bugfix/*`?** → continue to step 2.

**Otherwise**, create a branch from the remote base (then rebase in step 2):

```bash
git fetch origin
git checkout -b feature/<short-slug> origin/<base>   # new work
# or
git checkout -b bugfix/<short-slug> origin/<base>    # bug fixes
```

Naming rules:
- Use `feature/` for new capability or enhancement
- Use `bugfix/` when fixing a defect
- Slug: lowercase, hyphenated, derived from the task (e.g. `feature/add-retry-policy`)

If uncommitted changes exist, commit or stash before switching branches.

## 2. Rebase onto base

Keep the branch current with the remote base **before every push and before opening a PR**. Prefer rebase over merge.

```bash
git fetch origin
git rebase origin/<base>
```

**Rebase succeeds, branch never pushed** → continue to step 3.

**Rebase succeeds, branch already on remote** → push with lease:

```bash
git push --force-with-lease
```

**Conflicts during rebase:** → follow the `merge-conflicts` skill (or `rebase` skill for heuristics).

**Already up to date** (`git rebase origin/<base>` reports "Current branch … is up to date") → continue.

Re-run this step after fixing CI failures when the branch may have fallen behind base.

## 3. Commit and push

Only commit when there are changes to ship. Follow `writing-commit-messages` and the repo's style (`git log -5 --oneline`).

```bash
git status
git diff
git add <relevant files>
git commit -m "$(cat <<'EOF'
<type>: concise summary

Optional body explaining why.
EOF
)"
git push -u origin HEAD   # first push only; after a rebase use --force-with-lease
```

If step 2 already pushed via `--force-with-lease`, skip redundant push here unless new commits were added.

## 4. Create PR if missing

Check for an existing PR on this branch:

```bash
gh pr view --json number,url,state 2>/dev/null \
  || gh pr list --head "$(git branch --show-current)" --json number,url,state
```

**PR exists** → note the number/URL and go to step 5.

**No PR** → gather context, then create:

```bash
git status
git diff
git log origin/<base>...HEAD --oneline
git rev-parse --abbrev-ref @{upstream} 2>/dev/null; git status -sb
```

Create the PR:

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
- <1-3 bullets>

## Test plan
- [ ] <how to verify>
EOF
)"
```

Return the PR URL when done.

## 5. Watch CI

Watch checks for the current branch's PR until they finish:

```bash
gh pr checks --watch
```

Exit codes: `0` = all pass, `1` = at least one failed, `8` = still pending (without `--watch`).

**All checks pass** → go to step 7.

**Any check fails** → go to step 6.

Alternative when you need run-level logs:

```bash
gh run list --branch "$(git branch --show-current)" --limit 5
gh run watch <run-id>
```

## 6. Fix failures and retry

### Diagnose

```bash
gh pr checks --fail-fast
gh pr view --json statusCheckRollup,url
gh run view <run-id> --log-failed
```

Read only failed check names and relevant log sections — not full JSON dumps.

Classify the failure:
- **Caused by this branch** → fix in code/tests
- **Flaky or infra** → retry once (`gh run rerun <run-id>`); if still failing, report
- **Unrelated / base branch moved ahead** → re-run step 2 (rebase onto `origin/<base>`), then re-watch
- **Requires CI config change outside PR scope** → stop and report; do not weaken checks to pass

### Fix loop

1. Implement the minimal scoped fix
2. Run local verification when feasible (tests, lint)
3. Commit and push:

```bash
git add <files>
git commit -m "$(cat <<'EOF'
fix: <what failed and why>

EOF
)"
git push
```

4. Re-run **step 2** if the branch may be behind base
5. Return to **step 5** (`gh pr checks --watch`)

Repeat until all checks pass or you hit a blocker that needs user input.

## 7. Done

Report:
- Branch name
- PR URL
- CI status (all checks passing)
- Summary of fixes made during the retry loop (if any)

If comments or merge conflicts remain, hand off to the `babysit` skill for merge-readiness.

## Guardrails

- Never skip git hooks (`--no-verify`) unless the user explicitly requests it
- Never amend commits that were already pushed unless the user explicitly requests it
- Do not change CI workflows or checks just to make failures pass
- Do not push unrelated changes while fixing CI
- `--force-with-lease` after rebase is expected; ask before any other force-push, branch deletion, or closing/reopening the PR

## Reference commands

| Goal | Command |
|------|---------|
| Current branch | `git branch --show-current` |
| PR for branch | `gh pr view` |
| List open PRs | `gh pr list --head $(git branch --show-current)` |
| Watch CI | `gh pr checks --watch` |
| Failed checks | `gh pr checks --fail-fast` |
| Failed logs | `gh run view <id> --log-failed` |
| Rerun workflow | `gh run rerun <id>` |
| Rebase onto base | `git fetch origin && git rebase origin/<base>` |
| Push after rebase | `git push --force-with-lease` |
