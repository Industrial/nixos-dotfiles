---
name: activate-tooling
description: >-
  Activate and verify repo agent tooling (LeanCTX, Roam, Maestro, gh CLI, MCP servers). Use when starting a session or when a tool seems missing/unconfigured.
---

# activate-tooling

Checklist (from `.cursor/commands/activate.md`):

1. **LeanCTX:** `devenv shell -- lean-ctx cheatsheet` (daily workhorse: read/search/edit/shell/tree).
2. **Roam:** `devenv shell -- roam health` to verify codebase index.
3. **Maestro:** `devenv shell -- maestro status --json` (missions/tasks).
4. **GitHub CLI:** use `gh` for GitHub operations when needed.
5. Verify MCP servers from `.cursor/mcp.json` (lean-ctx, roam, maestro, searxng, serena).
6. If a server is down, see the `mcp-debug` skill.
