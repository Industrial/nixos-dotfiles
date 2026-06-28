---
name: hermes-lmstudio-connection
title: Connecting Hermes Agent to LM Studio Local Models
description: Guidance for configuring Hermes Agent to use LM Studio's built‑in OpenAI‑compatible API. Includes workflow, configuration commands, verification steps, and reference links.
---

## Overview
LM Studio runs a local OpenAI‑compatible server (default `http://localhost:1234/v1`; this install uses `11434`) when a model is loaded. Hermes Agent can consume this API directly – no intermediate wrapper scripts are required.

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
hermes config set model.default "qwen3.6-35b-a3b"
hermes config set model.context_length 65536
# 4. Tool-capable models (Qwen 3.6, Qwen3-Coder, etc.) use default hermes-cli toolsets.
#    Only disable tools for models with broken LM Studio jinja templates (e.g. Gemma 4 QAT):
# hermes config set platform_toolsets.cli '["no_mcp"]'
```

## Verification
```bash
# Quick sanity check: verify LM Studio API is accessible first
curl http://localhost:11434/v1/models
hermes chat -q "What is the capital of France?"
hermes chat -q "List the files in the current directory using your tools."
```
You should receive a response from the Qwen model; the second prompt should invoke terminal tools.

## Pitfalls & Tips
- **Port conflicts** – LM Studio defaults to `1234`. This install uses `11434`; update `base_url` to match your server.
- **Model name mismatch** – use the exact name shown by `curl http://localhost:11434/v1/models` (e.g. `qwen3.6-35b-a3b`).
- **Authentication** – LM Studio does not enforce an API key, but Hermes expects a key field; set it to an empty string.
- **Context length** – set at least `65536` for Hermes agent use; increase in LM Studio if VRAM allows.
- **Tool-calling / jinja template errors** – Qwen 3.6 and Qwen3-Coder work out of the box. Gemma 4 builds may fail with `UndefinedValue`; use `platform_toolsets.cli: [no_mcp]` for chat-only or fix the LM Studio prompt template.

## References
| Topic | Link |
|-------|------|
| LM Studio API documentation | https://lmstudio.ai/docs/api/overview |
| Hermes Agent configuration | `hermes config list` |
| OpenAI API compatibility notes | https://platform.openai.com/docs/api-reference/introduction |

---