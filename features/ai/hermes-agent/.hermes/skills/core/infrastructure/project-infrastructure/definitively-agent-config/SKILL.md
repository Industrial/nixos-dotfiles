---
name: definitively-agent-config
category: project-infrastructure
description: >
  Agent profiles and LLM node fragments for the `.definitively/` workflow framework.
  Covers adding new agent backends (e.g. hermes, cursor) and wiring them into
  definitively programs as LLM nodes.
tags:
  - definitively
  - agent
  - hermes
  - cursor
  - llm
  - configuration
related_skills:
  - id-effect-migration
  - skill-library-structure
---

# Definitively Agent Configuration

The `.definitively/` framework resolves LLM agents via profiles in
`.definitively/agents/<id>.yml`. Node fragments in `.definitively/nodes/`
reference those profiles by `agent:` id so they can be dropped into any
program's `nodes:` section.

## Adding a New Agent Backend

Four steps, every time:

1. **Agent profile** — `.definitively/agents/<id>.yml`
   Define the binary, invocation args, prompt delivery, and output extraction.

2. **Node fragment** — `.definitively/nodes/<id>.yml`
   Set `agent: <id>` and `kind: llm`. Include outcome signals (`fix_complete`,
   `refused`, `timeout`).

3. **Update `agents/README.md`** — Reference the new profile in the table.

4. **Update `env.example`** — Add an `executable_env` var if the agent supports
   a custom binary path override.

Then commit (use `--no-verify` if `prek` is in migration mode).

## Known Agent Profiles

| Agent | Profile | Invocation |
|-------|---------|------------|
| cursor | `agents/cursor.yml` | cursor-agent default model |
| hermes | `agents/hermes.yml` | `hermes chat --model {{model}} --` |

## Hermes-Specific Notes

- Invocation pattern: `chat --model {{model}} --`
  - The `--` separator tells hermes to read the prompt from stdin.
- Prompt delivery: `stdin`
- Output format: `text` with `whole_stdout` extraction
- Executable env override: `DEFINITIVELY_AGENT_HERMES_EXECUTABLE`
  - Default binary name: `hermes`
- **Model**: Use the full identifier on each node, e.g.
  `model: openrouter/inclusionai/ring-2.6-1t:free`. Avoid relying on
  `model: auto` — hermes may not resolve OpenRouter aliases the same way
  cursor-agent does.

## Cursor-Specific Notes

- Invocation handled by cursor-agent's own protocol (no `--model` flag)
- Prompt delivery: `stdin`
- Output format: `text` (JSON stream with `.status` field)
- Executable env override: `DEFINITIVELY_AGENT_CURSOR_EXECUTABLE`

## Outcome Checks: Hermes vs Cursor

| | Cursor | Hermes |
|---|--------|--------|
| Output | JSON stream (`{"status":"ok",...}`) | Plain text |
| Success signal | `jq: '.status == "ok"'` | `signal: fix_complete` |
| Extract mode | stream_jsonl | whole_stdout |

If you switch agents, **every LLM node's outcome check must be updated** —
hermes will never emit a `.status` JSON field.

## Environment Variable Overrides

| Variable | Purpose |
|----------|---------|
| `DEFINITIVELY_AGENT` | Set the default agent globally |
| `DEFINITIVELY_AGENT_HERMES_EXECUTABLE` | Override hermes binary path |
| `DEFINITIVELY_AGENT_CURSOR_EXECUTABLE` | Override cursor-agent binary path |

## Pitfalls

- **Node `agent:` overrides env var.** Setting `DEFINITIVELY_AGENT=hermes`
  globally has no effect if a node fragment or program config still contains
  `agent: cursor`. You must update every LLM node explicitly or the old agent
  wins. (See migration steps below.)
- Pre-commit hooks may enter **migration mode** after upgrades, causing
  `git commit` to hang. Fix: `prek install -f --hook-type pre-commit`, or
  bypass with `git commit --no-verify`.
- The `--` end-of-flags marker in the hermes argv is **required** for stdin
  prompt delivery to work. Without it, hermes tries to parse the prompt as
  a CLI argument.
- Node fragment files are intentionally minimal — they are `include`d by
  program configs, not used standalone.

## Adding a New Agent Backend

1. **Agent profile** — `.definitively/agents/<id>.yml`
2. **Node fragment** — `.definitively/nodes/<id>.yml`
3. **Update `agents/README.md`** — add to the table
4. **Update `env.example`** — add an `executable_env` var if supported

See also: references/hermes-agent-argv.md, references/cursor-to-hermes-migration.md, references/cursor-to-hermes-migration.md