# MCP Tool Selection Guide

This document defines the priority order and use cases for each MCP server
used with Hermes Agent. Load the mcp-tool-selection skill at session start to apply these rules automatically.

## Priority Order

| Priority | Server      | Purpose                      | When to use                                                       |
|----------|-------------|------------------------------|--------------------------------------------------------------------|
| 1        | roam-code   | Codebase navigation            | Finding call sites, tracing symbols, mapping dependencies BEFORE editing |
| 2        | context7    | Library docs lookup            | Current API docs for third-party libraries; do not rely on training data |
| 3        | lean-ctx    | Context compression            | After large roam/serena outputs, long sessions approaching context limit |
| 4        | serena      | Semantic code editing          | Renaming symbols, moving code, structural edits — prefer over text find/replace |

## Tool Selection Rules

- Always run **roam-code preflight** before making any structural change with **serena**
- Use **context7** when the task involves third-party APIs (e.g., Python library functions, npm packages)
- Compress with **lean-ctx** when intermediate output exceeds ~50% of context budget
- **serena edit tools** are for write-time only — do not use `execute_shell_command` as a write substitute

## Fallback Behavior

If an MCP server fails to initialize (e.g., import error for `StdioServerParameters`), fall back to the native Hermes tool with same functionality. Log the failure but do not block the session.