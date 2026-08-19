# Agent Instructions

## Cursor config (submodule)

`.cursor/` is the [Industrial/cursor-setup](https://github.com/Industrial/cursor-setup) submodule. After clone:

```bash
git submodule update --init --recursive .cursor
devenv shell   # imports `.cursor/nix` — lean-ctx, roam, maestro, serena, assay, moon, …
```

Shared tooling is provisioned via `cursor.features.*` in root `devenv.nix` (same pattern as other Industrial repos; no separate top-level `nix/` facade).

## Git pre-push (deepsec)

With the dev shell active, devenv installs a **pre-push** hook that runs `bin/git-hooks/deepsec-pre-push`. It invokes `deepsec process` (via `nix develop .deepsec`) on the commit range being pushed and **rejects the push** if deepsec exits non-zero (reported findings or AI stage failure).

- **Skip when needed:** `DEEPSEC_PRE_PUSH_SKIP=1 git push …`
- **Agent:** defaults to `claude` (matches `.deepsec`); override with `DEEPSEC_PRE_PUSH_AGENT=codex` if you use Codex credentials instead.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
4. **Clean up** - Clear stashes, prune remote branches
5. **Verify** - All changes committed AND pushed
6. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
