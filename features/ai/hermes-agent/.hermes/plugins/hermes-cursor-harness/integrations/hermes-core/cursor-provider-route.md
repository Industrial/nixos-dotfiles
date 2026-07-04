# Native Hermes `cursor/*` Provider Route

The plugin reaches the practical ceiling of the current public Hermes plugin
API: tools, slash commands, skill registration, session storage, Cursor SDK,
Cursor ACP, stream-json fallback, Cursor-to-Hermes MCP context, diagnostics,
compatibility records, and Background Agents helpers.

A true model-route experience such as `model: cursor/default` requires a Hermes
core provider patch, because plugins cannot currently replace the LLM execution
loop or register arbitrary model providers. A local implementation now exists in
the sibling Hermes checkout at:

```text
../_research/hermes-agent/
```

It adds:

- `agent/cursor_harness_adapter.py`
- `provider: cursor-harness`
- `api_mode: cursor_harness`
- `cursor/default`, `cursor/auto`, and live Cursor model discovery
- an `AIAgent.run_conversation()` branch that delegates the turn to this
  plugin while Hermes keeps session state, hooks, callbacks, and persistence
- durable mapping from `hermes_session_id` to `harness_session_id`
- live Cursor event callback plumbing back into Hermes stream/status callbacks

## Target Semantics

```text
model: cursor/default
provider: cursor-harness
```

Hermes would:

- keep the outer chat/session/transcript/tool policy
- detect `cursor/*` model IDs
- call the same harness runner used by this plugin
- stream normalized Cursor events into Hermes UI/gateway output
- store `harness_session_id` and `cursor_session_id` in Hermes session metadata
- resume the same Cursor session on follow-up turns

Cursor would:

- own repo-local reasoning, edits, shell/tool activity, and its model choice
- expose live events over the official Cursor SDK when available
- fall back to ACP when SDK auth/runtime is unavailable
- fall back to `agent -p --trust --output-format stream-json`

## Core Patch Shape

1. Add provider registry entry:

```yaml
provider: cursor-harness
models:
  - cursor/default
  - cursor/auto
  - cursor/composer-2
```

2. In the model/provider resolver, detect:

```python
if provider == "cursor-harness" or model.startswith("cursor/"):
    return CursorHarnessProvider(...)
```

3. Implement provider adapter:

```python
class CursorHarnessProvider:
    def run_conversation(self, messages, stream_delta_callback=None, **kwargs):
        prompt = render_messages_for_cursor(messages)
        result = hermes_cursor_harness.harness.run_turn(...)
        for event in result.events:
            stream_delta_callback(normalize_for_hermes(event))
        return result.text
```

4. Store harness metadata in Hermes session state:

```json
{
  "cursor_harness": {
    "harness_session_id": "...",
    "cursor_session_id": "...",
    "transport": "sdk",
    "sdk_run_id": "..."
  }
}
```

5. Preserve this plugin as the implementation package so users can update the
harness independently of Hermes core release cadence.

## Harness Commands

The plugin can validate a Hermes checkout for these native route markers:

```text
Use cursor_harness_provider_route with action=status, hermes_root=/path/to/hermes.
```

It can also write an upstreaming/install checklist bundle:

```text
Use cursor_harness_provider_route with action=bundle.
```

When the supplied `hermes_root` is a git checkout with these provider-route
changes, the bundle also includes `cursor-provider-route.patch` for review or
PR preparation.

## Verified Locally

```bash
cd hermes-cursor-harness
/opt/anaconda3/bin/python3 -m pytest -q
```

Result:

```text
68+ passed in the plugin package after the SDK-first hardening pass
```

```bash
cd _research/hermes-agent
.venv/bin/python -m pytest -q -o addopts='' tests/test_cursor_harness_provider.py
```

Result:

```text
3 passed
```

Real Cursor provider-route smoke:

```text
provider=cursor-harness
api_mode=cursor_harness
model=cursor/default
transport=sdk|acp|stream
final_response="hermes provider cursor route ok"
success=true
```

## Why The Boundary Still Exists

The plugin API can add tools, context, smoke suites, Cursor-side MCP context,
and Background Agents helpers, but it cannot currently short-circuit Hermes'
LLM provider execution. That is the one missing seam for full `cursor/*` model
selection parity in upstream Hermes. The local core patch supplies that seam;
upstreaming or packaging it is the remaining distribution step.
