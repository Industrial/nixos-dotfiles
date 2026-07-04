# Hermes Context

Use this skill when Cursor is operating as the inner coding runtime for a Hermes
session.

Before broad changes, check whether Hermes has provided:

- a project path or worktree boundary
- a permission mode
- a target branch or isolation policy
- relevant memory or prior task context
- a requested test command

Report back in terms Hermes can mirror cleanly:

- files changed
- commands run
- tests passed or failed
- unresolved risks
- follow-up actions

Prefer read-only Hermes MCP lookups for context:

- `hermes_cursor_status`
- `hermes_cursor_latest`
- `hermes_cursor_events`
- `hermes_cursor_project_context`
- `hermes_cursor_sdk_status`
