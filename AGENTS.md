# Agent Instructions

## Dev environment

The devenv modules this repo uses are vendored in `nix/devenv-modules/`
(formerly the `.cursor` submodule, Industrial/cursor-setup) and enabled with
`local.features.*` in root `devenv.nix`. Agent tooling (lean-ctx, roam-code,
maestro, claude-code, context7) is **not** in the devenv: it comes from the
host, `features/ai/*`.

Run toolchain commands with `bin/with-devenv <cmd>` (e.g.
`bin/with-devenv assay run .`). It gives the command the shell's packages and
env without entering `devenv shell`. Git hooks run through the same wrapper,
and entering the shell no longer runs them. Previously, shell entry ran
`prek run -a`, and hooks that re-entered the shell recursed.

## Hosts, profiles, features

Features are switched on by option, not imported by path. Every host gets every
entry of `features/catalog.nix` (each wrapped by `lib/features.nix`, which declares
`features.<path>.enable`, default off) and every `profiles/*.nix` (each declaring
`profiles.<name>.enable`). `hosts/<name>/configuration.nix` enables profiles and
features; a profile's choice is overridden per host with `lib.mkForce false`.

- New feature: add its path to `features/catalog.nix`, then set
  `features.<category>.<name>.enable = true;` in a profile or host.
- Host facts (roles, builders, operator keys, tailnet IPs) live in
  `common/fleet.nix`. Features read it; they never name hosts.
- `features.<…>` / `profiles.<…>` selections are cheap to test with
  `evalSelection` from `lib/features.nix`; see `profiles/*.assay.nix`.

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
