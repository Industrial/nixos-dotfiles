# omniroute gateway aliases (captured 2026-08-13)

Default Hermes `base_url` is `http://127.0.0.1:20128/v1` (local `omniroute`,
pid listens on 0.0.0.0:20128). It is a ROUTING layer, not a plain OpenRouter
proxy. It exposes abstract aliases; the upstream model-resolution is internal.

## How aliases behave
- `auto/*` — auto-selects among the gateway's available upstream models.
- `oc/*-free` — provider-specific free-tier routing.
- `ddgw/*`, `aug/*`, `tllm/*`, `pepper/*`, `veo-free/*`, `mcode/*`, `no-think/*`
  — namespaced endpoints (proxy passthroughs / alternate pools).

## Aliases observed via GET /v1/models (subset relevant to free/default)
- auto/best-coding, auto/best-reasoning, auto/best-fast, auto/best-vision,
  auto/best-chat, auto/best-coding-fast
- auto/pro-coding, auto/pro-reasoning, auto/pro-vision, auto/pro-chat, auto/pro-fast
- auto/coding, auto/fast, auto/chat, auto/cheap, auto/offline, auto/smart
- auto/claude-opus, auto/claude-sonnet
- auto/best-free            ← "best available free model" (use this for "any free model")
- auto/coding:free, auto/coding:cheap, auto/coding:pro, auto/coding:reliable
- auto/reasoning, auto/reasoning:pro, auto/vision, auto/multimodal
- auto/glm, auto/minimax, auto/mimo, auto/zai, auto/gemma, auto/llama, auto/gemini
- oc/big-pickle, oc/deepseek-v4-flash-free, oc/minimax-m3-free, oc/minimax-m2.5-free,
  oc/ling-2.6-1t-free, oc/trinity-large-preview-free, oc/nemotron-3-super-free,
  oc/qwen3.6-plus-free

## Error transcripts (raw upstream ids vs gateway aliases)

Raw OpenRouter free id through gateway — FAILS:
  model: tencent/hy3:free
  -> {"error":{"message":"No active credentials for provider: tencent",
      "type":"invalid_request_error","code":"model_not_found"}}

Raw OpenRouter free id through gateway — FAILS (same shape, any prefix):
  tencent/hy3:free, google/gemma-4-31b-it:free, openai/gpt-oss-20b:free,
  nvidia/nemotron-3-ultra-550b-a55b:free, cohere/north-mini-code:free,
  liquid/lfm-2.5-2.6b:free, poolside/laguna-s-2.1:free
  all -> "No active credentials for provider: <prefix>"

Paid ids through gateway — also FAIL (gateway uses its own cred pool, not shell env):
  tencent/hy3, tencent/hy3-preview, anthropic/claude-3.5-haiku, openai/gpt-4o-mini
  all -> "No active credentials for provider: <prefix>"

Gateway aliases through gateway — FAIL at runtime (creds exhausted, NOT config):
  auto/best-chat  -> "Maximum combo retry limit reached"
  auto/best-coding-> "Maximum combo retry limit reached"
  auto/best-fast  -> "Maximum combo retry limit reached"
  auto/best-free  -> "Maximum combo retry limit reached" (server_error / service_unavailable)
  auto/coding:free-> "Upstream response failed quality validation: response is not valid JSON"
  auto/cheap      -> "Upstream response failed quality validation: response is not valid JSON"
  auto/offline    -> "Maximum combo retry limit reached"
  oc/nemotron-3-super-free -> "[401]: Model nemotron-3-super-free is not supported"
  oc/deepseek-v4-flash-free -> "[429]: Rate limit exceeded. Please try again later."

## Interpretation
- "No active credentials for provider: X" = wrong id class (raw upstream id
  passed to a gateway that wants its own aliases). Fix: use `auto/*` or `oc/*-free`.
- "Maximum combo retry limit reached" / quality-validation errors = gateway
  upstream creds currently exhausted or degraded. The alias is CORRECT; wait for
  recovery. This is transient runtime state, not a config defect.
- None of the above means Hermes config is wrong when `model.default` is set to
  a valid gateway alias like `auto/best-free`.

## OpenRouter public API reality check (for contrast)
- OpenRouter free ids DO exist publicly (15 as of 2026-08-13) but the gateway
  cannot serve them by raw id. Also: `openrouter/auto` and `tencent/hy3:free`
  both return 404 against `https://openrouter.ai/api/v1/models`. So there is no
  OpenRouter-native "any free model" id — the gateway alias `auto/best-free` is
  the right abstraction for this setup.
