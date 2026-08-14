---
name: hermes-omniroute-routing
description: Configure Hermes Agent to route inference through Tom's local `omniroute` gateway (the default base_url), with emphasis on selecting a free / auto-routing model. Covers the valid routing aliases, why raw OpenRouter free ids fail, how to set `model.default`, and how to verify routing. Use when the user asks to use a free model, switch the default Hermes model, or debug gateway "No active credentials" / "Maximum combo retry" errors.
category: hermes
---

# Hermes ↔ omniroute model routing

## Trigger
Use this skill when:
- The user asks to "use a free model", "any available free model", "switch to free", or "pick the cheapest model" in Hermes.
- The user asks how to change the Hermes default model or provider.
- `model.default` must point at a routing alias rather than a concrete upstream id.
- Inference through the local gateway fails with `No active credentials for provider: X` or `Maximum combo retry limit reached`.

## Key facts (Tom's setup)
- Hermes `model.default` MUST be a concrete model id. There is NO keyword like "auto" or "free" that Hermes itself understands. To get "any free model", you point `model.default` at a gateway routing alias that performs the selection.
- The default `base_url` in `~/.hermes/config.yaml` is `http://127.0.0.1:20128/v1` — the local `omniroute` gateway, NOT OpenRouter directly. `omniroute` is a routing layer (see `/home/tom/.dotfiles/features/ai/omniroute/README.md`), not a plain proxy.
- OpenRouter has NO `:free` catch-all and NO `openrouter/auto` alias (verified: both return 404). Listing OpenRouter's real free ids (e.g. `tencent/hy3:free`, `nvidia/nemotron-3-ultra-550b-a55b:free`) and setting them as `model.default` will FAIL through the gateway with `No active credentials for provider: <prefix>`, because the gateway maps the id prefix to a credential pool and has no free creds for those prefixes.
- The CORRECT "any free model" setting is the gateway alias `auto/best-free`. Related aliases: `auto/coding:free`, `auto/cheap`, `auto/offline`, `auto/best-chat`, `auto/best-coding`, `auto/best-fast`; provider-specific free: `oc/deepseek-v4-flash-free`, `oc/minimax-m3-free`, `oc/nemotron-3-super-free`, `oc/ling-2.6-1t-free`, `oc/trinity-large-preview-free`, `oc/qwen3.6-plus-free`. Full alias list with tested behavior: `references/gateway-aliases.md`.

## How to set it
```
hermes config set model.default auto/best-free
```
This writes to `~/.hermes/config.yaml`. The change takes effect on the NEXT Hermes session/restart, not the currently running one. Verify the file line `model:` → `default:` after running.

## Verification (reproducible probe)
Run `scripts/probe-gateway.sh` to:
1. GET the gateway's `/v1/models` and print available aliases.
2. POST a tiny chat completion to a candidate alias.
3. Report `OK` / `ERR` so you can confirm routing before declaring success.

Always verify through the gateway (127.0.0.1:20128), NOT the OpenRouter public API — the two credential pools differ. A model that works against `https://openrouter.ai/api/v1` may still fail through the gateway.

## Pitfalls
- `Maximum combo retry limit reached` from the gateway = the gateway's pooled upstream credentials are currently exhausted / rate-limited. This is a RUNTIME state, NOT a config error. The alias is valid; wait for creds to recover or check the omniroute feature status. Retrying immediately just re-fails.
- `No active credentials for provider: X` = you set a raw upstream id (e.g. `tencent/hy3:free`, `nvidia/...`) that the gateway cannot map to a credential pool. Switch to an `auto/*` or `oc/*-free` alias.
- `auto/best-chat`, `auto/best-coding`, etc. also fail with "Maximum combo retry" when upstream creds are exhausted — same root cause as the free aliases.
- The gateway exposes many `auto/*` and provider-namespaced ids that are NOT real OpenRouter ids. Trust the gateway's `/v1/models` list, not OpenRouter's public catalog, when routing through omniroute.
- A model switched mid-session does not affect the running session; only new sessions pick up the new `model.default`.

## References
- `references/gateway-aliases.md` — captured alias list and tested error transcripts from the investigation session.
