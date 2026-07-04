# Cursor Harness

Use this skill when Hermes should delegate repository coding work to Cursor
while Hermes keeps the outer session, policy, and event trail.

Prefer this sequence:

1. Call `cursor_harness_doctor` before the first use in a session.
2. Call `cursor_harness_sdk` with `action=status`; use `action=install` if the SDK bridge is not installed.
3. Call `cursor_harness_config` with `action=validate` when diagnosing setup.
4. Call `cursor_harness_smoke` with `level=quick` when validating an install.
5. Use `cursor_harness_models` when the user asks which Cursor-backed models are available.
6. Use `cursor_harness_run` with `transport=auto` or `transport=sdk` and `mode=plan` for inspection or design work.
7. Use `mode=edit` only when the user has asked for file changes.
8. Use `cursor_harness_events` to inspect the event trail for a harness session.
9. Use `cursor_harness_diagnostics` when a user asks for a support bundle or failure report.
10. Use `cursor_harness_provider_route` to validate native `cursor/*` model routing in a Hermes checkout.
11. Use `cursor_harness_approvals` to list or decide pending approval bridge requests.
12. Use `cursor_harness_proposal_inbox` or `cursor_harness_proposals` to list or resolve Cursor-originated handoffs.

Permission modes:

- `plan`: read-only/planning; safest default.
- `ask`: read-only Q&A style where supported.
- `edit`: allow normal Cursor edit behavior.
- `full_access`: broad local approval behavior; use only after explicit user intent.
- `reject`: reject ACP permission requests and map stream fallback to plan mode.

Transport behavior:

- `auto`: try Cursor SDK first, then ACP, then stream-json.
- `sdk`: use Cursor's official `@cursor/sdk` bridge and Cursor-native local or cloud runtime.
- `acp`: use Cursor Agent ACP server mode.
- `stream`: use Cursor Agent `stream-json`.

Trusted read-only Hermes MCP backchannel calls may be allowed once even in
plan/ask/reject modes so Cursor can inspect Hermes session context without
gaining broad tool access.

For two-way Cursor/Hermes context, call `cursor_harness_install_companion` on
the project. It writes `.cursor/mcp.json`, a project rule, a skill, and a
Cursor plugin skeleton so Cursor can query Hermes Cursor Harness session context.
The companion also exposes non-read-only writeback tools:
`hermes_cursor_append_event` for session mirroring and `hermes_cursor_propose`
for reviewable handoffs. Treat those as requests to Hermes, not permission for
Cursor to mutate Hermes memory, policy, tools, or task state.

For long remote jobs against GitHub repositories, use
`cursor_harness_background_agent` after the user has configured a Cursor
Background Agents API key.

Use `cursor_harness_security_profiles` to inspect named policy profiles before
switching a run into broader local or background-agent behavior.

For Hermes UI-native approvals, configure `approval_bridge_command` to run
`hermes-cursor-harness approval-bridge`. The bridge writes pending approval
requests to harness state and waits for Hermes UI or the `cursor_harness_approvals`
tool to select an ACP option.
