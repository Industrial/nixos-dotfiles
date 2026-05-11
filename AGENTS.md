# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Git pre-push (deepsec)

With the dev shell active, devenv installs a **pre-push** hook that runs `bin/git-hooks/deepsec-pre-push`. It invokes `deepsec process` (via `nix develop .deepsec`) on the commit range being pushed and **rejects the push** if deepsec exits non-zero (reported findings or AI stage failure).

- **Skip when needed:** `DEEPSEC_PRE_PUSH_SKIP=1 git push …`
- **Agent:** defaults to `claude` (matches `.deepsec`); override with `DEEPSEC_PRE_PUSH_AGENT=codex` if you use Codex credentials instead.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

