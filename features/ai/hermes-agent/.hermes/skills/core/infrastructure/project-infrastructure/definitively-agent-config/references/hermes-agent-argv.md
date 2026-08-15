# Hermes Agent Invocation

## Argv Pattern

```
hermes chat --model <model> --
```

The `--` end-of-flags marker is critical — everything after it (including the
prompt) is read from stdin. Without it, hermes interprets the prompt text as
additional CLI arguments and fails.

## Model Selection

Use `--model <model>` where `<model>` is the model identifier string supported
by the hermes CLI (e.g. `llama3.1`, `mistral`, etc.). The definitively node
fragment uses `model: auto` to let the framework resolve the appropriate model.

## Prompt Delivery

- **Method**: stdin
- **Format**: Raw text prompt piped to hermes after the `--` separator
- **Output**: Whole stdout captured as the response text

## Example Invocation

```bash
echo "What is the yield on SOL?" | hermes chat --model llama3.1 --
```

## Environment Override

Set `DEFINITIVELY_AGENT_HERMES_EXECUTABLE` to point to a custom binary path
(e.g. `$HOME/.hermes/bin/hermes` on NixOS/home-manager setups). Falls back to
`hermes` on PATH if unset.