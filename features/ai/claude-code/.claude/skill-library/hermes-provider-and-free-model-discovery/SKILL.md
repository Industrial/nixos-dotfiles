---
name: hermes-provider-and-free-model-discovery
description: Techniques for enumerating which AI model providers Hermes can connect to, and which offer free-to-use model tiers. Covers source-level provider discovery, API-based free model enumeration, and local/self-hosted options.
category: hermes
---

# Hermes Provider and Free Model Discovery

Enumerate which AI model providers Hermes can connect to, and which of those
offer free-to-use model tiers.

## When to Use

- Answering "what free models can Hermes use?"
- Determining whether Hermes supports a specific new provider
- Auditing all available providers for a cost-free setup
- Troubleshooting missing providers in the picker

## Method 1: List all Hermes-supported providers (source of truth)

Hermes maintains a canonical provider list in its Python package.

```bash
# Find the installed package location
python3 -c "from hermes_cli.models import CANONICAL_PROVIDERS; [print(p.slug, p.label) for p in CANONICAL_PROVIDERS]"
```

If the CLI is not importable (e.g. on Nix managed installs), locate the package
and grep:

```bash
find /nix/store -maxdepth 1 -name "hermes-agent-*" -type d 2>/dev/null
PKG=$(find /nix/store -maxdepth 1 -name "hermes-agent-*" -type d 2>/dev/null | head -1)
grep -n "ProviderEntry(" "$PKG/lib/python3.13/site-packages/hermes_cli/models.py"
```

Provider plugins live at:
`$PKG/lib/python3.13/site-packages/plugins/model-providers/<slug>/`

The `custom` provider (aliases: `ollama`, `local`, `vllm`, `llamacpp`) covers
any OpenAI-compatible endpoint the user configures.

## Method 2: Discover free models per provider

### OpenRouter (widest free selection)

```bash
curl -s "https://openrouter.ai/api/v1/models" | python3 -c "
import sys, json
data = json.load(sys.stdin)
free = [m for m in data['data']
        if float(m['pricing']['prompt']) == 0
        and float(m['pricing']['completion']) == 0]
for m in sorted(free, key=lambda m: m['context_length'], reverse=True):
    mod = m.get('architecture',{}).get('modality','')
    has_tools = 'tool' in m.get('description','').lower()
    print(f\"{m['id']} | ctx={m['context_length']//1024}K | {mod}\" + (' [tools]' if has_tools else ''))
"
```

### Nous Portal (Hermes native, OAuth login)

```bash
curl -s "https://portal.nousresearch.com/api/nous/recommended-models" | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
for m in data.get('freeRecommendedModels', []):
    print(m.get('modelName'), m.get('tokenPrice'), 'vision=' + str(m.get('isVisionModel',False)))
"
```

### models.dev (provider/model index)

```bash
curl -s "https://models.dev/api.json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for p in sorted(d.keys()):
    models = d[p].get('models',{})
    if isinstance(models, dict):
        print(f'{p}: {len(models)} models')
"
```

Note: models.dev does NOT carry per-model pricing for most providers. Use the
direct provider API (e.g. OpenRouter above) for pricing/free detection.

## Method 3: Check the Hermes model catalog

```
https://hermes-agent.nousresearch.com/docs/api/model-catalog.json
```

Lists `openrouter` and `nous` as the two aggregator-style providers Hermes
curates models for. Direct providers (Anthropic, OpenAI, etc.) are in
CANONICAL_PROVIDERS but absent from this catalog.

## Method 4: Local / self-hosted (always free)

| Provider slug | Setup | Cost |
|---|---|---|
| `lmstudio` | Local desktop app | Free |
| `custom` (alias: ollama) | Local Ollama instance | Free |
| `custom` | vLLM, llama.cpp, any OpenAI-equiv endpoint | Free |
| `huggingface` | HF_TOKEN (free) | 30K chars/month free |
| `custom` | Cloudflare Workers AI endpoint | 10K neurons/day free |

## Quick reference: which providers have free access?

### Always free / has free tier
1. **openrouter** — 23+ free models across many model families
2. **nous** — Free OAuth login; free-recommended model list
3. **custom** — Local models (Ollama, LM Studio, vLLM, llama.cpp)
4. **huggingface** — 30K chars/month free tier on Inference API

### Paid-only (no free tier)
anthropic, openai-api, openai-codex, gemini, deepseek, xai, zai, nvidia,
minimax, stepfun, moonshotai, tencent-tokenhub, bedrock, azure-foundry,
groq, together, arcee, gmi, novita, kilocode, opencode-zen, opencode-go,
copilot, copilot-acp, qwen-oauth

### Pitfalls

### "Free" model has hidden usage limits
Many "free" models on OpenRouter and Nous Portal are rate-cimited or
queuable. They rarely have hard daily caps but can be deprioritized during
peak load. For production agent tasks, consider the cheapest paid tiers
(e.g. `deepseek/deepseek-v4-flash` at $0.00008/1k tokens on OpenRouter).

### models.dev doesn't include pricing
The models.dev API gives model counts and existence but almost never includes
pricing. Always check the provider's own API or pricing page for free-tier
confirmation.

### Nous Portal free models change
The Portal's `/api/nous/recommended-models` endpoint is the live source of
truth. Free models rotate based on partnerships. Don't hardcode a specific
free model slug from today — use the endpoint at query time.

### Hugging Face provider only uses `HF_TOKEN`, not `HUGGING_FACE_HUB_TOKEN`
The Hugging Face provider in Hermes (`huggingface`, aliases: `hf`, `hugging-face`, `huggingface-hub`)
only reads the `HF_TOKEN` environment variable for authentication. If you set
`HUGGING_FACE_HUB_TOKEN` in your `.hermes/.env`, it will be ignored. Use:
```bash
HF_TOKEN=hf_xxxxxxxxxxxx
```
The provider uses the Inference Providers router at `https://router.huggingface.co/v1`
with these curated agentic models:
- `moonshotai/Kimi-K2.5`
- `Qwen/Qwen3.5-397B-A17B`
- `Qwen/Qwen3.5-35B-A3B`
- `deepseek-ai/DeepSeek-V3.2`
- `MiniMaxAI/MiniMax-M2.5`
- `zai-org/GLM-5`
- `XiaomiMiMo/MiMo-V2-Flash`
- `moonshotai/Kimi-K2-Thinking`
- `moonshotai/Kimi-K2.6`

Free tier: 30K characters/month on Hugging Face Inference API.
