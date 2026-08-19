# Temporal skills for Cursor

Official Temporal agent skills from [temporalio](https://github.com/temporalio) installed under `.cursor/skills/temporal/`.

**3 skills** with extensive `references/` trees (TypeScript, Go, Python, Java, .NET, Ruby, Rust).

## Quick pick

| Task | Skill |
|------|-------|
| Build/debug workflows, workers, CLI | `skill-temporal-developer` |
| Design durable workflows (patterns, sagas) | `skill-temporal-design` |
| Temporal Cloud setup & operations | `skill-temporal-cloud` |

## Catalog

### skill-temporal-developer

Primary development skill. Covers:

- Cluster vs worker architecture, task queues, history replay
- Determinism, non-determinism errors, versioning, continue-as-new
- Signals, queries, updates, child workflows, activities, heartbeats
- Temporal CLI: `temporal server start-dev`, workflow start/execute/signal/query
- Per-SDK references under `references/` (use **`references/typescript/`** for this monorepo)

**Repo context:** `@temporalio/*` ~1.11 in `apps/risk-calculator`; local stack `docker compose up -d temporal temporal-ui` (`TEMPORAL_ADDRESS=127.0.0.1:7233`, UI `:8233`). Temporal MCP server configured in `.cursor/mcp.json`.

### skill-temporal-design

Workflow design patterns before implementation — compensation, saga, entity workflows, long-running processes.

### skill-temporal-cloud

Namespaces, certificates, Cloud CLI, production deployment concerns.

## Related in this repo

- Workflows: `apps/risk-calculator` (e.g. case lifecycle)
- MCP: `project-0-monorepo-temporal` in `.cursor/mcp.json`
- Devenv prints Temporal address on shell enter

## Sources & licenses

| Source | Skills | License |
|--------|--------|---------|
| [temporalio/skill-temporal-developer](https://github.com/temporalio/skill-temporal-developer) | 1 | See upstream (LICENSE in repo) |
| [temporalio/skill-temporal-design](https://github.com/temporalio/skill-temporal-design) | 1 | See upstream |
| [temporalio/skill-temporal-cloud](https://github.com/temporalio/skill-temporal-cloud) | 1 | See upstream |

Installed from upstream **main** (May 2026). Each skill includes a `references/` directory with SDK-specific deep dives.

## Updating

```bash
TMP=$(mktemp -d)
for repo in skill-temporal-developer skill-temporal-design skill-temporal-cloud; do
  git clone --depth 1 "https://github.com/temporalio/${repo}.git" "$TMP/$repo"
  rm -rf ".cursor/skills/temporal/$repo"
  cp -a "$TMP/$repo" ".cursor/skills/temporal/$repo"
done
find .cursor/skills/temporal -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true
```
