# Cursor → Hermes Migration Reference

## Context

The solana-yield-optimizer project switched from `agent: cursor` to
`agent: hermes` with model `openrouter/inclusionai/ring-2.6-1t:free` across
all `.definitively/` program configs.

## What Changed

### Agent Profile
- **Before**: `agents/cursor.yml` — cursor-agent, no `--model` flag, JSON stream output
- **After**: `agents/hermes.yml` — hermes CLI, `--model {{model}} --`, plain text output

### Node Fragments
- **Before**: `nodes/llm.yml` with `agent: cursor`, `model: auto`
- **After**: `nodes/hermes.yml` with `agent: hermes`, explicit model per node

### Outcome Checks
- **Before**: `jq: '.status == "ok"'` (cursor emits JSON with `.status` field)
- **After**: `signal: fix_complete` (hermes emits plain text, uses signal-based detection)

### Programs Updated
- `dev-quality-loop.yml` — 7 LLM nodes
- `pre-commit-loop.yml` — 2 LLM nodes
- `pre-push-loop.yml` — 4 LLM nodes
- `backtest-fix-loop.yml` — 1 LLM node
- `scrutinize-pre-ship.yml` — 1 LLM node
- `post-mortem-close.yml` — 1 LLM node
- `debug-fix-loop.yml` — 1 LLM node
- `hyperopt-fix-loop.yml` — 1 LLM node

### Environment
- `DEFINITIVELY_AGENT` default changed from `cursor` to `hermes`
- `DEFINITIVELY_AGENT_CURSOR_EXECUTABLE` replaced by
  `DEFINITIVELY_AGENT_HERMES_EXECUTABLE=$HOME/.hermes/bin/hermes`

## Verification

```bash
# Confirm zero cursor references remain
grep -r "agent: cursor" .definitively/

# Run a program end-to-end
export DEFINITIVELY_AGENT=hermes
export DEFINITIVELY_AGENT_HERMES_EXECUTABLE=$HOME/.hermes/bin/hermes
definitively run .definitively/programs/dev-quality-loop.yml
```