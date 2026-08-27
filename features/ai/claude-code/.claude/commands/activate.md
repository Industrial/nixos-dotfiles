1. **LeanCTX:** Run `devenv shell -- lean-ctx cheatsheet` (daily workhorse: read/search/edit/shell/tree).
2. **Roam:** Run `devenv shell -- roam health` to verify codebase index.
3. **Maestro:** Run `devenv shell -- maestro status --json` (missions/tasks).
4. **GitHub CLI:** Use the `gh` cli for GitHub when needed.
5. Verify MCP servers from `.cursor/mcp.json`:

   **Always on:** lean-ctx · roam-code · context7 · searxng · github (official Docker image) · maestro

   **On demand** (set `disabled: false` when needed): rust-docs · nats · docker · postgres · questdb · mcp-debugger · definitively · temporal · playwright · chrome-devtools · figma-mcp-go

   **Secrets:** `GITHUB_PERSONAL_ACCESS_TOKEN` for github MCP (fine-grained PAT).
