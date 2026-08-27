---
name: pre-push-ci
description: >-
  Run bun run ci:pre-push Maestro-centrically: create small Maestro tasks/specs for each problem found (including other libs in the monorepo) and finish them one by one.
---
# pre-push-ci

I want you to use Maestro-centric development. As you run `bun run ci:pre-push`, for each problem found create simple small Maestro tasks (or specs). Include problems, type errors etc found in other libraries and places around the monorepo. Finish the Maestro tasks one by one.

## Pitfalls

### A panic / 500 in CI is rarely the root cause

When `bun run ci:pre-push` (or a later CI lane) surfaces a Turbopack panic, an `Error: Missing data` from `Config.string`, or a 500 from `test-nextjs` with `test-nextjs (healthy)` in `docker compose ps`, the panic/error itself is usually a **symptom**: process.env was frozen at import, an init-volume file is unreadable across users, or some other timing/permission boundary. The break lies upstream of the panic.

Default workflow:

1. Generate the Maestro task with the literal CI error.
2. Suspect the runtime environment first (env-load order, init perms, missing env vars) before debugging the build/run code.
3. After the fix, re-run the failing lane. The original panic often disappears because it was triggered by the upstream miss.
