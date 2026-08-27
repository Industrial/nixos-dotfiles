# Mode: EXECUTE

`[ID:EXECUTE]`

## Goal

Implement one approved leaf within Maestro contract scope.

## Steps

1. Confirm human approval (or single-pass plan+implement).
2. Claim on the **current branch** (no worktree):
   ```bash
   devenv shell -- maestro task claim <tsk-id> --agent <agent-id> --skip-worktree --tool <tool>
   ```
   Then `maestro_contract_show`. Do **not** call MCP `maestro_task_claim` — it auto-creates heavy-mode worktrees with no skip flag.
3. Implement only contracted paths on the checked-out branch; amend contract if scope grows legitimately.
4. Record evidence after each gate; prefer Definitively / Moon gates for this repo.
5. Follow `.cursor/skills/maestro/implement-hierarchical-plan` when waves apply (same no-worktree claim rule).

## Writes

Contract-scoped code and tests. No drive-by refactors.

## Exit

Leaf AC met + evidence recorded → REVIEW.
