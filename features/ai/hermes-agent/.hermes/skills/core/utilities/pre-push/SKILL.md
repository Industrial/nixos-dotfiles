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