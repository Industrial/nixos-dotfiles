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

Use writeback tools only for mirroring or handoff:

- `hermes_cursor_append_event` for progress, warnings, and results tied to a
  known harness session
- `hermes_cursor_propose` for memory updates, task updates, tool requests,
  questions, handoffs, or suggested Hermes actions that Hermes must review

Do not treat writeback as permission. In plan or ask mode, do not edit files
unless Hermes explicitly grants that mode.
