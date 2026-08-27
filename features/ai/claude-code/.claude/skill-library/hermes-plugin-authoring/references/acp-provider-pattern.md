# ACP Model-Provider Plugin Pattern

Reference for implementing ACP subprocess model-provider plugins in the
hermes-agent dotfiles repo. Synthesized from the cursor-acp implementation
(2026-05-28) which mirrors the upstream copilot-acp plugin.

## What ACP is

Agent Client Protocol — JSON-RPC over stdio. Spec: https://agentclientprotocol.com
Both `gh copilot agent acp` and `cursor agent acp` speak this protocol.
Hermes has an ACP adapter layer (acp_adapter/ in upstream) that acts as the
server side; the CLI binary is the client/subprocess.

## ProviderProfile fields for ACP providers

```python
MyACPProfile(
    name="my-acp",
    aliases=("my", "my-acp-alias"),
    api_mode="chat_completions",    # ACP subprocess routes internally as chat_completions
    env_vars=(),                    # NO API key env var — auth is via local credential file
    base_url="acp://my-provider",   # SENTINEL — not a real HTTP URL
    auth_type="external_process",   # tells Hermes: skip credential checks entirely
)
```

## The dispatch table (run_agent.py)

If the upstream run_agent.py has a generalised ACP dispatch table, it looks
like this and lives at module level:

```python
ACP_SUBPROCESS_COMMANDS: dict[str, list[str]] = {
    "acp://copilot": ["gh", "copilot", "agent", "acp"],
    "acp://cursor":  ["cursor", "agent", "acp"],
    # add new ACP providers here
}
```

When adding a new ACP provider, check whether this table exists:

```bash
grep -n "acp://" run_agent.py hermes_cli/runtime_provider.py
```

- If table exists: add your entry; plugin alone is sufficient.
- If Copilot-specific (hardcoded `gh copilot agent acp`): refactor to table,
  add both copilot and cursor entries.

## The shortcut table (delegate_task acp_command)

```python
ACP_COMMAND_SHORTCUTS: dict[str, list[str]] = {
    "copilot": ["gh", "copilot", "agent", "acp"],
    "cursor":  ["cursor", "agent", "acp"],
}
```

This maps the acp_command= string a user passes to delegate_task to an actual
subprocess command list.

## auth_type="external_process" bypass

In hermes_cli/auth.py or runtime_provider.py there should be a branch:

```python
if provider_config.auth_type == "external_process":
    return RuntimeProvider(
        provider=provider_config.id,
        api_mode=provider_config.api_mode,
        base_url=provider_config.base_url,
        api_key=None,
        source="external_process",
    )
```

Verify with:
```bash
grep -n "external_process" hermes_cli/auth.py hermes_cli/runtime_provider.py
```

If not present (path falls through to "missing credentials"), add the branch.

## Known ACP providers (as of 2026-05-28)

| Provider    | base_url        | Command                    | Auth file                       |
|-------------|-----------------|----------------------------|---------------------------------|
| copilot-acp | acp://copilot   | gh copilot agent acp       | GH CLI keyring / gh auth login  |
| cursor-acp  | acp://cursor    | cursor agent acp           | ~/.cursor/cli-config.json       |

## Pitfalls

- Never add a `CURSOR_API_KEY` or similar env var check for ACP providers.
  They use OAuth via local credential files. An API key check produces false
  "missing credentials" errors.
- Never make HTTP requests to an `acp://` URL. It is a sentinel value only.
- The `cursor` CLI must be installed and the user logged in before this
  provider works. Smoke-test: `cursor agent acp --version` and check for
  `~/.cursor/cli-config.json`.
- Model availability depends on the user's Cursor subscription tier
  (Hobby / Pro / Business). Hermes cannot enforce this — errors from the ACP
  subprocess surface as normal Hermes errors.
