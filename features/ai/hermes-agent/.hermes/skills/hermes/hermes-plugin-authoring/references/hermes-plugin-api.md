# Hermes Plugin API — Reference

Sourced from Context7 (/nousresearch/hermes-agent) during session 2026-05-26.

## Discovery

Hermes discovers plugins from three places (in order):
1. `~/.hermes/plugins/<name>/`
2. `./.hermes/plugins/<name>/`
3. pip/Nix entry points: `[project.entry-points."hermes_agent.plugins"]`

For Nix-managed dotfiles, use entry points (option 3) via extraPlugins in
hermes-agent/package.nix.

## ctx API (register function argument)

```python
# Register a tool (exposed to the LLM as a callable tool)
ctx.register_tool(
    name="tool_name",       # snake_case, unique across all plugins
    toolset="my_plugin",    # groups tools in hermes tools list
    schema=SCHEMA_DICT,     # JSON-schema dict
    handler=handler_fn,     # callable(params: dict, **kwargs) -> str (JSON)
    description="...",      # optional override of schema description
)

# Register a lifecycle hook
ctx.register_hook(event, handler_fn)
# Events:
#   "pre_tool_call"    — before any tool runs
#   "post_tool_call"   — after any tool runs
#   "pre_llm_call"     — before LLM inference
#   "post_llm_call"    — after LLM inference
#   "on_session_start" — once at session start
#   "on_session_end"   — once at session end

# Register a platform adapter (messaging gateway)
ctx.register_platform(
    name, label, adapter_factory, check_fn,
    required_env, env_enablement_fn,
    cron_deliver_env_var, emoji, platform_hint,
)

# Register a CLI subcommand (hermes <subcommand>)
ctx.register_cli_command(...)
```

## Hook handler signatures

post_tool_call:
    def handler(tool_name, args, result, task_id, **kwargs): ...

on_session_start / on_session_end:
    def handler(**kwargs): ...
    # kwargs includes: task_id, session, agent

## Tool handler return

Always return a JSON string. Never raise — return error JSON instead:

    return json.dumps({"success": True,  "result": ...})
    return json.dumps({"success": False, "error": str(e)})

## Nix: extraPythonPackages vs extraPlugins

The upstream NixOS module uses `services.hermes-agent.extraPythonPackages`.
Tom's dotfiles don't use the NixOS module — they use a manual package.nix
with an `extraPlugins ? []` argument and propagatedBuildInputs. Both achieve
the same result (plugin on PYTHONPATH → importlib.metadata discovery).
