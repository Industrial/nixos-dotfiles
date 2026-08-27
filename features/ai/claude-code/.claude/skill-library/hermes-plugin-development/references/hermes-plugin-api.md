# Hermes Plugin API — condensed reference
# Source: Context7 /nousresearch/hermes-agent (queried 2026-05-26)

## ctx methods available in register(ctx)

| Method | Signature | Purpose |
|--------|-----------|---------|
| `register_tool` | `(name, toolset, schema, handler, description=None)` | Expose a tool to the LLM |
| `register_hook` | `(event, fn)` | Tap a lifecycle event |
| `register_platform` | `(name, label, adapter_factory, check_fn, required_env, ...)` | Full messaging-platform adapter |
| `register_cli_command` | `(...)` | Add subcommands to the `hermes` CLI |

## Hook events

| Event | When it fires | Handler kwargs |
|-------|--------------|----------------|
| `pre_tool_call` | Before any tool runs | `tool_name, args, task_id` |
| `post_tool_call` | After any tool runs | `tool_name, args, result, task_id` |
| `pre_llm_call` | Before LLM API call | `messages, task_id` |
| `post_llm_call` | After LLM API call | `messages, response, task_id` |
| `on_session_start` | Session initialisation | `task_id` |
| `on_session_end` | Session teardown | `task_id` |

Always accept `**kwargs` — Hermes may inject additional keys in future versions.

## plugin.yaml fields

```yaml
name: string           # required
version: string        # required (semver)
description: string    # required
author: string         # optional
homepage: url          # optional
provides_tools: []     # list of tool names registered via ctx.register_tool
provides_hooks: []     # list of hook events registered via ctx.register_hook
requires_env: []       # list of env var names — gates plugin loading
```

`requires_env` can be simple strings (`- MY_TOKEN`) or rich objects:
```yaml
requires_env:
  - name: MY_TOKEN
    description: "API token for My Service"
    url: https://myservice.example.com/tokens
    secret: true
```

## Discovery order

1. `~/.hermes/plugins/<name>/`
2. `./.hermes/plugins/<name>/` (project-local)
3. pip entry points: `[project.entry-points."hermes_agent.plugins"]`

## Tool handler contract

```python
def my_handler(params: dict, **kwargs) -> str:
    # params: validated against the schema
    # kwargs: task_id, session, agent, ... (Hermes-injected)
    return json.dumps({"success": True, ...})
    # On error: return json.dumps({"success": False, "error": "message"})
    # Do NOT raise — return the error in JSON.
```

## Nix — extraPythonPackages vs propagatedBuildInputs

The upstream Nix docs show `services.hermes-agent.extraPythonPackages` for
NixOS module installs. In this dotfiles repo (no NixOS module, manual
`buildPythonApplication`), the equivalent is passing the plugin derivation
via `propagatedBuildInputs` through an `extraPlugins ? []` argument.

Both approaches end up adding the package to PYTHONPATH so `importlib.metadata`
can find the `hermes_agent.plugins` entry point.
