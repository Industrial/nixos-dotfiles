---
name: mcp-tool-selection
description: |
  This skill defines the priority order and use cases for each MCP server used with Hermes Agent. Load at session start to automatically select the best tool for your context.
---

# MCP Tool Selection

## Priority Order

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

## Fallback Behavior
If an MCP server fails to start (e.g., missing Python `mcp` dependency), fall back to the native Hermes tool of the same name and log the incident.
