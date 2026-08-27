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
   - If MCP server is unreachable, fall back to: `devenv shell -- cat /path/to/lean-ctx/cheatsheet.md` or inspect files directly with terminal commands
   - Continue to next step even if this fails

2. **Roam:** Run `devenv shell -- roam health` to verify codebase index.
   - If MCP server is unreachable, fall back to: `devenv shell -- roam` commands directly or skip if persistently failing
   - Continue to next step even if this fails

3. **Maestro:** Run `devenv shell -- maestro status --json` (missions/tasks).
   - If MCP server is unreachable, fall back to: `devenv shell -- maestro status` or check `.maestro/` directory directly
   - Continue to next step even if this fails

4. **GitHub CLI:** Use the `gh` cli for GitHub when needed.
   - This typically works outside of devenv/MCP

5. Verify MCP servers from `.cursor/mcp.json`:

   **Always on:** lean-ctx · roam-code · context7 · searxng · github (official Docker image) · maestro

   **On demand** (set `disabled: false` when needed): rust-docs · nats · docker · postgres · questdb · mcp-debugger · definitively · temporal · playwright · chrome-devtools · figma-mcp-go

   **Secrets:** `GITHUB_PERSONAL_ACCESS_TOKEN` for github MCP (fine-grained PAT).

## Fallback Procedures

When MCP servers are persistently unreachable during activation:

1. **File Operations:** Use regular terminal commands (`cat`, `grep`, `sed`, etc.) outside devenv shell for inspection and basic fixes
2. **Environment Access:** Use `devenv shell -- <command>` to run specific commands without relying on MCP servers
3. **Prioritize Progress:** If an MCP-dependent step fails repeatedly, note the issue and continue with other activation steps
4. **Document Issues:** Record which MCP servers failed for later troubleshooting

## Verification

After running these commands, you should see:
- LeanCTX cheatsheet displayed (or accessible via fallback)
- Roam health check passes (green status) or alternative verification
- Maestro status shows current missions/tasks or accessible via fallback
- GitHub CLI is ready for use
- MCP servers are connected and responsive (or documented failures with fallbacks in place)

This ensures your Hermes Agent session has access to the codebase intelligence, task management, and external services needed for productive work, even when some MCP servers experience connectivity issues.