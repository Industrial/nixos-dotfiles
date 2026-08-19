---
name: hermes-enable-mcp-servers
description: Enable and verify Hermes MCP servers (lean-ctx, roam, maestro, context7, searxng) for this monorepo.
---

# Enable Hermes MCP servers

Project Hermes uses MCP from devenv PATH. Config lives in `$HERMES_HOME/config.yaml` under `mcp_servers`.

## Checklist

1. Confirm `HERMES_HOME=$PWD/.hermes` and `TERMINAL_ENV=docker`.
2. Ensure MCP entries in config match templates at `nix/features/hermes-agent/templates/config.yaml`.
3. Run `hermes mcp` / doctor as available to verify servers start.
4. Never commit `.env` or `auth.json`.
