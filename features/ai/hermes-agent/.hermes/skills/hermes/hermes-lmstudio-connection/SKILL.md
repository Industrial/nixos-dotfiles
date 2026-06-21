---
name: hermes-lmstudio-connection
title: Connecting Hermes Agent to LM Studio Local Models
description: Guidance for configuring Hermes Agent to use LM Studio's built‑in OpenAI‑compatible API. Includes workflow, configuration commands, verification steps, and reference links.
---

## Overview
LM Studio runs a local OpenAI‑compatible server (default `http://localhost:11434/v1`) when a model is loaded. Hermes Agent can consume this API directly – no intermediate wrapper scripts are required.

## Configuration Steps
```bash
# 1. Ensure LM Studio is running with the desired model loaded.
# 2. Point Hermes at the LM Studio OpenAI-compatible server.
#    Hermes 0.14+ uses model.provider (not the legacy provider.local block).
hermes config set model.provider lmstudio
hermes config set model.base_url "http://localhost:11434/v1"
hermes config set model.api_mode chat_completions
# LM Studio does not require an API key; leave it empty.
hermes config set model.api_key ""
# 3. Select the model (must match GET /v1/models exactly).
hermes config set model.default "gemma-4-26b-a4b-it-qat"
# 4. If the model's LM Studio prompt template lacks tool support, disable
#    Hermes tools for CLI chat (otherwise LM Studio returns jinja errors).
hermes config set platform_toolsets.cli '["no_mcp"]'
```

## Verification
```bash
# Quick sanity check: verify LM Studio API is accessible first
curl http://localhost:11434/v1/models
hermes chat -q "What is the capital of France?"
```
You should receive a response from the Gemma model.

## Pitfalls & Tips
- **Port conflicts** – LM Studio defaults to `11434`. If you change the port, update `base_url` accordingly.
- **Model name mismatch** – use the exact name shown by `curl http://localhost:11434/v1/models` (e.g. `gemma-4-26b-a4b-it-qat`, not `14b`).
- **Authentication** – LM Studio does not enforce an API key, but Hermes expects a key field; set it to an empty string.
- **Tool-calling / jinja template errors** – many local Gemma builds in LM Studio fail when Hermes sends tool schemas (`Cannot call something that is not a function: got UndefinedValue`). Workarounds:
  - Chat-only: `platform_toolsets.cli: [no_mcp]` (disables Hermes + MCP tools for CLI).
  - Full agent: load an `lmstudio-community` build with a fixed prompt template, or override the template in LM Studio (**My Models → model settings → Prompt Template**), then restore `platform_toolsets.cli` to `["hermes-cli"]` (or run `hermes tools` to re-enable).

## References
| Topic | Link |
|-------|------|
| LM Studio API documentation | https://lmstudio.ai/docs/api/overview |
| Hermes Agent configuration | `hermes config list` |
| OpenAI API compatibility notes | https://platform.openai.com/docs/api-reference/introduction |

---