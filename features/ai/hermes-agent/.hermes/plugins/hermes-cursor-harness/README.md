# Hermes Cursor Harness

Hermes Cursor Harness is an experimental Hermes plugin that makes Cursor a
first-class embedded coding runtime for Hermes.

This is intentionally **not** just a `cursor-agent` shell wrapper. The harness
keeps Hermes-owned session records, stores Cursor event streams, maps safe
permission modes, talks to Cursor's official `@cursor/sdk` first, and falls
back to ACP and Cursor Agent `stream-json` when the SDK path is unavailable.

## What Exists In This First Cut

- Hermes plugin toolset: `cursor_harness`
- SDK-first execution through Cursor's official `@cursor/sdk`
- Local or cloud SDK runtime selection
- SDK model/catalog/account/repository status helpers
- ACP fallback through `agent acp`, `cursor-agent acp`, or `cursor agent acp`
- `stream-json` fallback through `agent -p --output-format stream-json`
- Durable Hermes-side session registry under `~/.hermes/cursor_harness/`
- Cursor session ID tracking for resume/load-capable transports
- Event JSONL logs per harness session
- Cursor-to-Hermes event and proposal backchannel for review-gated handoffs
- Terminal and JSON proposal inbox surfaces for Hermes UI/reviewer workflows
- Permission modes: `plan`, `ask`, `edit`, `full_access`, `reject`
- Tool handlers:
  - `cursor_harness_run`
  - `cursor_harness_status`
  - `cursor_harness_events`
  - `cursor_harness_doctor`
  - `cursor_harness_models`
  - `cursor_harness_sdk`
  - `cursor_harness_latest`
  - `cursor_harness_install_companion`
  - `cursor_harness_smoke`
  - `cursor_harness_background_agent`
  - `cursor_harness_provider_route`
  - `cursor_harness_diagnostics`
  - `cursor_harness_compatibility`
  - `cursor_harness_config`
  - `cursor_harness_session`
  - `cursor_harness_security_profiles`
  - `cursor_harness_approvals`
  - `cursor_harness_proposals`
  - `cursor_harness_proposal_inbox`
- Fake Cursor SDK/ACP/stream fixtures and tests
- Optional Cursor plugin/MCP/rules/skills companion for the Cursor side of the bridge
- One-command smoke suite for quick, real, and full verification passes
- One-command release gate through `scripts/release_check.sh`
- Hermes UI and Hermes core integration contracts under `integrations/`
- Tiny demo project under `examples/demo_project/`
- Cursor Background Agents API helpers for long-running remote jobs

## Architecture

```text
Hermes outer runtime
  session, memory, tools, approvals, transcripts, delivery

Hermes Cursor Harness
  provider/tool layer, session registry, event normalization, permission mapping

Cursor inner runtime
  Cursor SDK, ACP server, or stream-json agent; repo reasoning, edits,
  shell/tool events, model choice, Cursor MCP/skills/hooks/subagents
```

Primary path:

```text
Hermes -> cursor_harness_run -> @cursor/sdk -> Cursor Agent runtime
```

Backchannel path:

```text
Cursor -> Hermes MCP -> session event mirror and reviewable proposal queue
Hermes -> cursor_harness_proposals -> accept, reject, mark done, or archive
```

ACP fallback path:

```text
Hermes -> cursor_harness_run -> Cursor ACP server -> Cursor Agent runtime
```

Stream fallback path:

```text
Hermes -> cursor_harness_run -> cursor-agent --output-format stream-json
```

## Install Into Hermes

From this repo:

```bash
./install.sh
```

Then enable the plugin in `~/.hermes/config.yaml`:

```yaml
plugins:
  enabled:
    - hermes-cursor-harness
```

Enable the toolset wherever you run Hermes:

```yaml
platform_toolsets:
  cli:
    - hermes-cli
    - cursor_harness
```

## Configure

Create `~/.hermes/cursor_harness.json`:

```json
{
  "transport": "auto",
  "sdk_runtime": "local",
  "sdk_package": "@cursor/sdk@latest",
  "sdk_auto_install": true,
  "sdk_setting_sources": ["project", "user", "team", "plugins"],
  "sdk_sandbox_enabled": true,
  "sdk_cloud_repository": "",
  "sdk_cloud_ref": "",
  "sdk_auto_create_pr": false,
  "projects": {
    "my-app": "/absolute/path/to/my-app"
  },
  "default_permission_policy": "plan",
  "trusted_readonly_mcp_tools": [
    "hermes_cursor_status",
    "hermes_cursor_latest",
    "hermes_cursor_events",
    "hermes_cursor_project_context",
    "hermes_cursor_sdk_status"
  ],
  "background_api_base_url": "https://api.cursor.com",
  "allow_background_agents": true,
  "security_profile": "",
  "security_profiles": {},
  "approval_bridge_command": ["hermes-cursor-harness", "approval-bridge"],
  "approval_bridge_timeout_sec": 120,
  "default_timeout_sec": 900,
  "no_output_timeout_sec": 120
}
```

Optional explicit commands:

```json
{
  "sdk_command": ["node", "/path/to/sdk_bridge.mjs"],
  "acp_command": ["agent", "acp"],
  "stream_command": ["agent"],
  "mcp_servers": []
}
```

Useful environment overrides:

```bash
export HERMES_CURSOR_HARNESS_TRANSPORT=acp
export HERMES_CURSOR_HARNESS_SDK_RUNTIME=local
export HERMES_CURSOR_HARNESS_SDK_SANDBOX_ENABLED=false
export HERMES_CURSOR_HARNESS_ACP_COMMAND="agent acp"
export HERMES_CURSOR_HARNESS_STREAM_COMMAND="agent"
```

Leave SDK sandboxing enabled by default. Set
`HERMES_CURSOR_HARNESS_SDK_SANDBOX_ENABLED=false` only when the Cursor SDK
reports that local sandboxing is unsupported in your environment.

Cursor and approval-bridge subprocesses run with a scoped child environment.
The harness forwards basic OS/runtime variables plus Cursor API credentials
where needed, but does not inherit unrelated provider, Gateway, GitHub, or shell
tokens from the Hermes process.

Install and check the official Cursor SDK bridge:

```bash
hermes-cursor-harness sdk install
hermes-cursor-harness sdk status
```

`transport=auto` tries SDK first, then ACP, then stream-json. Use
`transport=sdk` when you specifically want to exercise the official SDK path.
Use `sdk_runtime=cloud` plus a Cursor API key and a GitHub repository when you
want Cursor cloud agents instead of the local runtime.

The same stored Cursor API key is used for SDK catalog/cloud calls and
Background Agents:

```bash
hermes-cursor-harness api-key status
hermes-cursor-harness api-key set
hermes-cursor-harness api-key test
```

## Smoke Test

Ask Hermes:

```text
Use cursor_harness_doctor.
```

Then:

```text
Use cursor_harness_run with project=my-app, mode=plan, prompt="Inspect the repo and summarize the test command. Do not edit files."
```

For a structured self-test:

```text
Use cursor_harness_smoke with level=quick.
```

Quick smoke now includes the bidirectional backchannel regression check: Cursor
MCP append event, Cursor MCP proposal, Hermes resolution, and resolution-event
readback.

For structured config validation:

```text
Use cursor_harness_config with action=validate, project=my-app.
```

Review Cursor-to-Hermes proposals:

```bash
hermes-cursor-harness inbox --format text
hermes-cursor-harness proposals inbox
```

Hermes UI integrations should use the JSON contract in
`integrations/hermes-ui/proposal-inbox-contract.md`.

For real Cursor transport checks:

```text
Use cursor_harness_smoke with level=real, project=my-app.
```

For a real SDK transport check:

```text
Use cursor_harness_smoke with level=real, include_sdk=true, project=my-app.
```

For the full local gauntlet, including Cursor calling the Hermes MCP
backchannel and session-isolation checks:

```text
Use cursor_harness_smoke with level=full, project=my-app.
```

For an edit-capable run:

```text
Use cursor_harness_run with project=my-app, mode=edit, prompt="Fix the failing unit test and explain the diff."
```

Use `full_access` only when you want Cursor to receive broad local approval
behavior. The default is deliberately `plan`.

Permission behavior in this plugin is conservative:

- `plan` maps to Cursor plan/read-only behavior where supported.
- `sdk` transport currently enforces `plan`, `ask`, and `reject` by passing a
  Hermes policy preface into the SDK prompt and enabling Cursor's SDK sandbox
  option for local runs; ACP remains the strictest mid-turn approval surface.
- `ask` does not yet open an interactive Hermes approval UI; ACP permission
  requests are rejected unless they match a configured trusted read-only Hermes
  MCP backchannel tool.
- `edit` allows one ACP permission request at a time and lets stream-json use
  Cursor's normal edit mode.
- `full_access` may pass broad approval flags to Cursor Agent.
- `reject` maps stream-json fallback to plan mode and rejects ACP permissions
  unless they match a configured trusted read-only Hermes MCP backchannel tool.
- Cursor-side writeback tools are deliberately not trusted read-only tools.
  `hermes_cursor_append_event` records progress into an existing session, and
  `hermes_cursor_propose` creates a pending proposal. Neither one mutates
  Hermes memory, policy, tools, or task state by itself.
- The config loader and security-profile application reject those writeback
  tools if they appear in `trusted_readonly_mcp_tools`.

The stream-json fallback passes `--trust` for configured projects because Cursor
Agent otherwise blocks headless `--print` runs on workspace trust prompts. Keep
project aliases scoped to repositories you trust.

### Security Profiles And Approval Bridge

Built-in security profiles:

- `readonly`: plan/read-only local work; background agents disabled.
- `repo-edit`: focused local edit-mode work; background agents disabled.
- `trusted-local`: broad local approval behavior for trusted workspaces.
- `background-safe`: read-only local defaults while allowing Background Agents.

You can list profiles with:

```text
Use cursor_harness_security_profiles.
```

For non-whitelisted ACP permissions, the harness can call an external approval
bridge command:

```json
{
  "approval_bridge_command": ["/path/to/hermes-approval-bridge"],
  "approval_bridge_timeout_sec": 120
}
```

The command receives JSON on stdin containing the permission request and options,
and may return `{"optionId": "allow-once"}` or `{"outcome": "reject"}`.

The built-in bridge command is:

```json
{
  "approval_bridge_command": ["hermes-cursor-harness", "approval-bridge"],
  "approval_bridge_timeout_sec": 120
}
```

It writes pending requests to `~/.hermes/cursor_harness/approvals` and waits for
a decision. A Hermes UI can render those requests through the
`cursor_harness_approvals` tool, then decide with an allowed Cursor option ID:

```text
Use cursor_harness_approvals with action=list.
Use cursor_harness_approvals with action=decide, request_id=hca_..., option_id=allow-once.
```

### Cursor-To-Hermes Proposals

Cursor can call the MCP backchannel to send information back to Hermes while it
is doing repo work:

- `hermes_cursor_append_event`: append a Cursor-originated note, warning, or
  result to a known harness session.
- `hermes_cursor_propose`: create a reviewable proposal for Hermes, such as a
  memory update, task update, tool request, question, handoff, or suggested
  Hermes action.

Hermes owns resolution. Review proposals through the Hermes tool:

```text
Use cursor_harness_proposals with action=list.
Use cursor_harness_proposals with action=get, proposal_id=hcp_....
Use cursor_harness_proposals with action=accept, proposal_id=hcp_..., reason="Approved by user."
Use cursor_harness_proposals with action=reject, proposal_id=hcp_..., reason="Out of scope."
Use cursor_harness_proposals with action=done, proposal_id=hcp_....
```

For a Hermes UI-style inbox with linked session events:

```text
Use cursor_harness_proposal_inbox.
Use cursor_harness_proposals with action=inbox.
```

Proposal IDs are strict opaque IDs, and a proposal can only be resolved once.
Choose `accept`, `reject`, `done`, `archive`, or `cancel` as the terminal Hermes
decision for that handoff.

When a proposal is tied to a harness session, Hermes' resolution is appended to
that session as `cursor_companion_proposal_resolution`, so Cursor can later read
Hermes' decision through `hermes_cursor_events`.

The CLI exposes the same queue:

```bash
hermes-cursor-harness proposals list
hermes-cursor-harness proposals accept hcp_... --reason "Approved by user."
hermes-cursor-harness proposals reject hcp_... --reason "Out of scope."
```

## Cursor-Side Plugin Skeleton

The `cursor-plugin/hermes-harness/` directory is a starter package for the
Cursor side. Its job is to make Cursor aware that Hermes is available as context
and, once wired to a real Hermes MCP command, let Cursor ask Hermes for memory,
session, or task context.

This side is optional for the first Hermes-runner loop. It becomes important for
true back-and-forth behavior where Cursor can call Hermes while Cursor is doing
the coding work.

Install the companion into a project through Hermes:

```text
Use cursor_harness_install_companion with project=my-app.
```

This writes:

- `.cursor/mcp.json`
- `.cursor/rules/hermes-harness.mdc`
- `.cursor/skills/hermes-context.md`
- `.cursor/environment.json`
- `.cursor/plugins/hermes-harness/`

The MCP server command is installed as:

```bash
~/.local/bin/hermes-cursor-harness-mcp
```

It exposes context and review-gated writeback tools to Cursor:

- `hermes_cursor_status`
- `hermes_cursor_events`
- `hermes_cursor_project_context`
- `hermes_cursor_latest`
- `hermes_cursor_sdk_status`
- `hermes_cursor_append_event`
- `hermes_cursor_propose`

The first five are read-only context tools. The writeback tools are for session
mirroring and proposals only; Hermes still decides whether anything becomes
memory, task state, policy, or a tool action.

## Cursor Background Agents

The harness also exposes Cursor's public Background Agents API as an optional
remote execution lane. Set an API key from Cursor Dashboard -> Integrations.
The safest local path is macOS Keychain:

```bash
hermes-cursor-harness background-key set
hermes-cursor-harness background-key test
```

You can also provide `CURSOR_BACKGROUND_API_KEY` or `CURSOR_API_KEY` in the
process environment. The harness checks environment variables first, then the
Keychain entry named `cursor-background-api-key`.

Then use:

```text
Use cursor_harness_background_agent with action=list.
Use cursor_harness_background_agent with action=local_list.
Use cursor_harness_background_agent with action=launch, repository=https://github.com/org/repo, ref=main, prompt="Fix the failing test.", confirm_remote=true.
Use cursor_harness_background_agent with action=status, agent_id=bc_...
Use cursor_harness_background_agent with action=followup, agent_id=bc_..., prompt="Also update docs.", confirm_remote=true.
Use cursor_harness_background_agent with action=launch_from_latest, repository=https://github.com/org/repo, prompt="Continue from the latest harness session.", confirm_remote=true.
Use cursor_harness_background_agent with action=sync_result, agent_id=bc_...
```

Background agents run remotely against GitHub repositories and may auto-run
terminal commands. Use them for longer async jobs where that remote security
model is acceptable. Remote launch, follow-up, and delete actions require
explicit confirmation.

## Local Maintenance CLI

`./install.sh` installs two wrappers:

```bash
hermes-cursor-harness doctor
hermes-cursor-harness sdk install
hermes-cursor-harness sdk status
hermes-cursor-harness sdk models
hermes-cursor-harness api-key status
hermes-cursor-harness smoke --level quick
hermes-cursor-harness smoke --level real --project my-app
hermes-cursor-harness smoke --level real --project my-app --include-sdk
hermes-cursor-harness diagnostics
hermes-cursor-harness config validate
hermes-cursor-harness provider-route status --hermes-root /path/to/hermes
hermes-cursor-harness provider-route bundle --output-dir /tmp/cursor-route
hermes-cursor-harness compatibility run --level quick
hermes-cursor-harness compatibility run --level real --project my-app --include-sdk
hermes-cursor-harness profiles
hermes-cursor-harness approvals list
hermes-cursor-harness proposals list
hermes-cursor-harness inbox --format text
hermes-cursor-harness background-key status
hermes-cursor-harness background-key test
hermes-cursor-harness background local_list
hermes-cursor-harness background list --limit 5
hermes-cursor-harness config-template
hermes-cursor-harness uninstall
hermes-cursor-harness-mcp
```

## Provider Route, Diagnostics, Compatibility, Sessions

Native `model: cursor/default` requires the Hermes provider route. Validate a
Hermes checkout:

```text
Use cursor_harness_provider_route with action=status, hermes_root=/path/to/hermes.
```

Create an upstreaming/install bundle:

```text
Use cursor_harness_provider_route with action=bundle.
```

Create a redacted support bundle:

```text
Use cursor_harness_diagnostics.
```

Record a compatibility matrix entry:

```text
Use cursor_harness_compatibility with action=run, level=real, project=my-app.
```

Private CI can run the real Cursor SDK lane with `CURSOR_API_KEY` and optional
`CURSOR_AGENT_INSTALL_COMMAND` secrets through `.github/workflows/cursor-compatibility.yml`.

Manage sessions:

```text
Use cursor_harness_session with action=name, harness_session_id=hch_..., name="Release fix".
Use cursor_harness_session with action=tag, harness_session_id=hch_..., tags=["release","cursor"].
Use cursor_harness_session with action=export, harness_session_id=hch_....
Use cursor_harness_session with action=prune, keep_last=50, dry_run=true.
```

## Development

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -e ".[dev]"
.venv/bin/python -m pytest -q
```

The tests do not require Cursor. They use fake SDK, ACP, and stream-json processes.

## Release Packaging

This repo includes Python package metadata, CI templates, changelog, license,
and release notes:

- `pyproject.toml`
- `MANIFEST.in`
- `CHANGELOG.md`
- `LICENSE`
- `.github/workflows/ci.yml`
- `.github/workflows/cursor-compatibility.yml`
- `docs/RELEASE.md`
- `docs/DEMO.md`
- `docs/DISTRIBUTION.md`
- `docs/LAUNCH.md`
- `scripts/demo_approval_bridge.sh`
- `scripts/release_check.sh`

Run the public release gate locally with:

```bash
python -m pip install -e ".[dev,release]"
scripts/release_check.sh
```

## Current Limits

- The plugin/toolset works on stock Hermes. Native `cursor/*` model routing
  requires the Hermes core provider patch in `integrations/hermes-core/`; a
  local patched Hermes checkout has been verified.
- Cursor SDK cloud/catalog runs require Cursor's SDK authentication path and a
  Cursor API key. Auto transport falls back to ACP/stream-json when SDK is not
  available.
- ACP capability support depends on the installed Cursor CLI version.
- Interactive permission prompts are mapped by policy; Hermes UI-native
  mid-turn approval can use the built-in file-backed approval bridge, while the
  visual modal itself still lives in Hermes UI code.
- Cursor-side plugin schema is evolving, so treat that package as a skeleton.
- Background Agents API is beta and requires a Cursor Dashboard API key plus a
  GitHub repository Cursor can access.

## Next Milestones

1. Upstream the native `cursor/*` provider route into stock Hermes core.
2. Wire Hermes UI-native proposal and approval modals to the contracts under
   `integrations/hermes-ui/`.
3. Publish to PyPI/Homebrew/archive once package-owner credentials and the
   public package home exist.
4. Host the compatibility matrix generated by real Cursor SDK/CLI runs.
