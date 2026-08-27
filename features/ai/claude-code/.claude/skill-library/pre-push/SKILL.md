---
name: pre-push
description: >
  Use Maestro-centric development for pre-push checks. As you run bun run ci:pre-push, 
  for each problem found create simple small Maestro tasks (or specs). Include problems, 
  type errors etc found in other libraries and places around the monorepo. Finish the 
  Maestro tasks one by one.
tags: [pre-push, maestro, ci, quality-gates]
---

# Pre-Push Maestro-Centric Development

## Purpose
Use Maestro-centric development during pre-push checks. When running `bun run ci:pre-push`, 
for each problem found (type errors, lint issues, etc.), create simple small Maestro tasks 
or specs to track and fix them one by one.

## Workflow

1. Run your pre-push checks: `bun run ci:pre-push`
2. For each problem found:
   - Create a Maestro task or spec describing the issue
   - Include relevant details: file paths, error messages, reproduction steps
   - Add acceptance criteria for when the issue is resolved
3. Work through the Maestro tasks one by one:
   - Claim each task: `maestro task claim <id> --skip-worktree`
   - Implement the fix
   - Record evidence after each gate
   - Request and confirm verdict
   - Ship the task: `maestro task ship <id>`
4. Repeat until all pre-push issues are resolved

## Repo reality check — hook stack varies

`bun run ci:pre-push` is NOT universal. This dotfiles repo
(/home/tom/.dotfiles) gates commits/pushes through **prek + devenv** hooks
(auto-generated `.pre-commit-config.yaml`, marked DO NOT MODIFY):

- `moon test (assay)` → `devenv shell -- assay run .` — runs at **pre-commit**, not push
- `deepsec` → `devenv shell -- bin/git-hooks/deepsec-pre-push` — pre-push;
  bypass with `DEEPSEC_PRE_PUSH_SKIP=1`, agent override via DEEPSEC_PRE_PUSH_AGENT
- commitizen validates the commit message subject/body style

Gotchas learned the hard way:

1. Run git through the devenv environment: plain `git commit` fails with a
   bare `No such file or directory (os error 2)` because hook binaries
   aren't on PATH outside `devenv shell`.
2. prek evaluates the **exact tree being committed**: unstaged work is
   stashed and non-staged paths revert to HEAD inside the hook. A commit
   limited by pathspec to file A still runs tests against HEAD state of
   file B — so if HEAD contains broken suites, fix-and-commit them FIRST;
   you cannot smuggle a test repair into an unrelated feature commit.
3. Assay suites load repo-wide: one broken `*.assay.nix` blocks EVERY
   commit in the repo. When commits fail mysteriously, run
   `devenv shell -- assay run .` first and fix SuiteLoad errors before anything else.

## Benefits
- Turns ad-hoc fixing into tracked, verifiable work
- Provides clear acceptance criteria for each issue
- Enables parallel work on independent issues
- Creates audit trail of what was fixed and when
- Integrates with existing Maestro workflow and quality gates

## Example
When ci:pre-push finds a type error in `src/utils/helpers.ts:42`:
1. Create Maestro task: "Fix type error in helpers.ts line 42"
2. Add AC: "Type checker passes on helpers.ts"
3. Work through the task using Maestro claim→verify→ship cycle
4. Move to next issue

This approach ensures that pre-push maintenance becomes part of your structured development workflow rather than ad-hoc firefighting.