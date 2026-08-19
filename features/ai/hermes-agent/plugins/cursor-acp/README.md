# cursor-acp

Cursor CLI ACP model-provider plugin for Hermes Agent.

Routes Hermes conversations through `cursor agent acp` using the user's
existing Cursor subscription and the [Agent Client Protocol](https://agentclientprotocol.com)
(ACP) — JSON-RPC over stdio.

## How it works

`cursor agent acp` starts a stdio JSON-RPC server speaking ACP.
Hermes sees `base_url="acp://cursor"` and `auth_type="external_process"` on
the provider profile and hands the conversation to the ACP subprocess layer
instead of making HTTP requests.

Authentication is via `~/.cursor/cli-config.json` (your existing Cursor
login). No `CURSOR_API_KEY` is required or checked.

## Prerequisites

- Cursor CLI installed: `cursor --version`
- Logged in: `~/.cursor/cli-config.json` must exist
- A Cursor subscription that covers the model you select

## Usage

```bash
hermes config set provider cursor-acp
hermes config set model claude-sonnet-4-5   # or gpt-4o, cursor-small, etc.
hermes "say hello"
```

Or for a one-off session:

```bash
hermes --provider cursor-acp --model cursor-small "say hello"
```

## delegate_task routing

Inside a Hermes session, pass `acp_command="cursor"` to route a subagent
through cursor agent acp:

```
delegate_task(goal="say hello", acp_command="cursor")
```

## Verification

```bash
# 1. Plugin discovered
hermes plugins list | grep cursor

# 2. Provider in model picker
hermes model --list | grep cursor

# 3. Config round-trip
hermes config set provider cursor-acp
hermes config get provider   # should print cursor-acp

# 4. ACP binary smoke-test (requires cursor installed + logged in)
cursor agent acp --version

# 5. Live session
hermes "say hello"
```

## Structure

```
cursor-acp/
├── plugin.yaml          # Hermes plugin manifest
├── pyproject.toml       # Python package + hermes_agent.plugins entry point
├── package.nix          # Nix derivation
├── README.md            # This file
└── cursor_acp/
    └── __init__.py      # CursorACPProfile + register_provider() + register(ctx)
```

## Nix installation

The plugin is wired into `hermes-agent/default.nix` via `extraPlugins`.
Rebuild after any change:

```bash
nixos-rebuild switch
```
