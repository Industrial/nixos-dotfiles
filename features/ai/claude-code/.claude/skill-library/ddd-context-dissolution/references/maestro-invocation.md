# Maestro harness invocation in this repo (learned 2026-08-23)

The `maestro` binary is NOT on the devenv PATH even though the project is
maestro-initialized (`.maestro/` present, `maestro-task` skill auto-loads).

## Working invocation

```bash
export PATH="/nix/store/dlsk98hadp25cjcsjfrpy7vv7b1ldanz-maestro-0.106.1/bin:$PATH"
maestro status --json
```

If lean-ctx's shell allowlist blocks it:

```bash
lean-ctx allow maestro   # additive allowlist entry, takes effect immediately
```

## Session flow that worked end-to-end

1. `maestro spec new <slug> --title "..."` → writes `.maestro/specs/<slug>.md`
   with empty AC; fill `acceptance_criteria` / `non_goals` / frontmatter via
   file write before claiming.
2. `maestro task from-spec .maestro/specs/<slug>.md` → prints tsk id.
3. `maestro claim <id> --agent <name> --skip-worktree` (per repo rule: never
   MCP claim, no worktrees) — auto-locks a contract whose doneWhen mirrors AC.
4. Do the waves.
5. `maestro evidence record --task <id> --command "..." --exit 0` and
   `--kind manual-note --note "..."` for attribution notes.
6. `maestro verify <id>` → PASS auto-advances verifying→ready.
7. `maestro ship <id>`.

## Gotchas

- `status --json` output is huge (hundreds of tasks); head/grep it, and check
  for an existing task covering your area before creating a duplicate — an old
  blocked task may predate layout moves that already landed half of it
  (venue-abstraction tsk targeted deleted notebooks/ paths).
- devenv shell startup noise pollutes piped stdout; write command output to a
  file inside the invocation, then read the file.
