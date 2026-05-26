---
name: mcp-tool-selection
description: |
  This skill defines the priority order and use cases for each MCP server used with Hermes Agent. Load at session start to automatically select the best tool for your context.
---

## MCP Tool Selection

### Priority Order

| Priority | Server      | Purpose                      |
|----------|-------------|------------------------------|
| 1        | roam-code   | Codebase navigation          |
| 2        | context7    | Library docs lookup          |
| 3        | lean-ctx    | Context compression          |
| 4        | serena      | Semantic code editing        |

## Usage Rules
- Always run **roam-code** pre‑flight before making any structural edit with **serena**.
- Use **context7** when the task involves third‑party library APIs.
- Compress large intermediate outputs with **lean‑ctx** when the context budget exceeds ~50%.
- **serena** tools are write‑only; do not replace them with `execute_shell_command`.
- For web search tasks, note that no dedicated web search MCP server is configured by default. Use browser tools (with NixOS compatibility considerations) or terminal-based approaches like `curl` with search engines.

## NixOS Compatibility Notes
Browser tools may fail on NixOS systems with error: "Could not start dynamically linked executable" due to agent-browser requiring glibc. Workarounds:
1. Use terminal-based approach: `terminal(command="curl -s 'SEARCH_URL'")`
2. Use `execute_code` with Python requests library for scraping
3. Consider using DuckDuckGo's instant answer API: `https://api.duckduckgo.com/?q=QUERY&format=json`

## Fallback Behavior
If an MCP server fails to start (e.g., missing Python `mcp` dependency), fall back to the native Hermes tool of the same name and log the incident.

## Web Search Alternatives (Free/Open Source)
When MCP servers don't cover web search needs:
- DuckDuckGo HTML: `https://duckduckgo.com/html/?q=QUERY`
- DuckDuckGo Instant Answer API: `https://api.duckduckgo.com/?q=QUERY&format=json&pretty=1`
- Use browser tools with DuckDuckGo/Google (respecting rate limits)
- Terminal approach: `curl -s 'https://duckduckgo.com/html/?q=QUERY' | grep -A2 -B2 'result__snippet'`
