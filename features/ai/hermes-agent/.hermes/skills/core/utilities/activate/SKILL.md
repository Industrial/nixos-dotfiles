---
name: activate
description: >
  Session initialization routine for Hermes Agent. Verify and activate core MCP servers and tools.
  Use at the start of a session to ensure all necessary services are running and healthy.
tags: [initialization, setup, mcp, health-check]
---

# Session Activation

Run this initialization sequence at the start of your Hermes Agent session to verify all critical systems are operational.

## Steps

1. **LeanCTX:** Run `devenv shell -- lean-ctx cheatsheet` (daily workhorse: read/search/edit/shell/tree).
2. **Roam:** Run `devenv shell -- roam health` to verify codebase index.
3. **Maestro:** Run `devenv shell -- maestro status --json` (missions/tasks).
4. **GitHub CLI:** Use the `gh` cli for GitHub when needed.
5. Verify MCP servers from `.cursor/mcp.json`:

   **Always on:** lean-ctx · roam-code · context7 · searxng · github (official Docker image) · maestro

   **On demand** (set `disabled: false` when needed): rust-docs · nats · docker · postgres · questdb · mcp-debugger · definitively · temporal · playwright · chrome-devtools · figma-mcp-go

   **Secrets:** `GITHUB_PERSONAL_ACCESS_TOKEN` for github MCP (fine-grained PAT).

## Verification

After running these commands, you should see:
- LeanCTX cheatsheet displayed
- Roam health check passes (green status)
- Maestro status shows current missions/tasks
- GitHub CLI is ready for use
- All MCP servers are connected and responsive

This ensures your Hermes Agent session has full access to the codebase intelligence, task management, and external services needed for productive work.