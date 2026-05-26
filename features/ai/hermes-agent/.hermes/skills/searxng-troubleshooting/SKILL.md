---
name: searxng-troubleshooting
description: Debug SearXNG HTTP 403 and search failures. Use when SearXNG returns 403 on /search, MCP searxng client fails, or search results are empty. Covers both bot detection limiter and search.formats misconfiguration.
triggers:
  - searxng returns 403
  - mcp-searxng fails
  - searxng search not working
  - troubleshooting searxng
---

# Troubleshooting SearXNG

## Diagnosis: 403 on /search endpoint

Two independent causes both return HTTP 403 on `/search`:

### Cause A: Bot detection limiter
SearXNG's `limiter: true` activates HTTP header probes (`http_user_agent`, `http_accept`, `http_sec_fetch`, `http_accept_language`, `ip_limit`) that block non-browser clients.

**Symptoms:** 403 even with browser-like headers. Logs show `X-Forwarded-For nor X-Real-IP header is set!` or `botdetection` warnings.

**Fix:** In NixOS config:
```
services.searx.settings.server.limiter = false
```
For internet-facing instances, keep limiter on and configure `trusted_proxies` instead.

### Cause B: search.formats doesn't include requested format (MOST COMMON)
SearXNG's default `search.formats` is `["html"]` only. When a client requests `?format=json` (e.g., mcp-searxng MCP client), the handler calls `flask.abort(403)`.

**Symptoms:** 403 specifically on `?format=json`. Main page (`/`) returns 200. Config endpoint shows `"formats": ["html"]`.

**Fix:**
```
services.searx.settings.search.formats = [ "html" "json" "csv" "rss" ]
```

**Verification:**
```
curl -s http://localhost:PORT/search?q=test&format=json
```

### Cause C: Both A and B combined
Both fixes required simultaneously.

## Relevant files (NixOS)
- Config: features/network/searx/default.nix in dotfiles repo
- Runtime settings: /run/searx/settings.yml (written by searx-init service)
- Logs: journalctl -u searx
- See references/searxng-nixos-config.md for full NixOS config template, pitfalls, and debug commands

## SearXNG config debug checklist
1. Check running config: curl -s http://localhost:PORT/config
2. Check for 403 vs 429: 403 = format not allowed or limiter; 429 = rate limited
3. Verify search.formats includes "json" for MCP client compatibility
4. Verify server.limiter=false for local/non-browser access
