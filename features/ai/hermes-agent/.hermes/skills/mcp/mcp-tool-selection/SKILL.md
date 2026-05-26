---
name: mcp-tool-selection
description: |
  This skill defines the priority order and use cases for each MCP server used with Hermes Agent. Load at session start to automatically select the best tool for your context.
---

## MCP Tool Selection

### Priority Order

| Priority | Server      | Purpose                      |
|----------|-------------|------------------------------|
| 1        | roam-code   | Codebase navigation          |
| 2        | context7    | Library docs lookup          |
| 3        | lean-ctx    | Context compression          |
| 4        | serena      | Semantic code editing        |
| 5        | searxng     | Web search via self-hosted SearXNG |

## Usage Rules
- Always run **roam-code** pre‑flight before making any structural edit with **serena**.
- Use **context7** when the task involves third‑party library APIs.
- Compress large intermediate outputs with **lean‑ctx** when the context budget exceeds ~50%.
- **serena** tools are write‑only; do not replace them with `execute_shell_command`.
- Use **searxng** for web search tasks when available.

## SearXNG Troubleshooting

### Symptom: MCP calls return HTTP 403 "Authentication required or IP blocked"

There are **two independent causes** of 403 on SearXNG's `/search` endpoint. Check both.

---

### Cause 1: Bot detection limiter

SearXNG's limiter blocks non-browser requests via `http_user_agent`, `http_accept`, and `http_sec_fetch` filters.

**Fix**: Disable the limiter in NixOS config:
```nix
services.searx.settings.server.limiter = false;
```
Then `sudo nixos-rebuild switch`. Safe for local/internal instances.

---

### Cause 2: `search.formats` doesn't include `json`

The `/search` handler checks `settings.search.formats` and returns 403 if the requested format isn't listed. The default is `["html"]` only. The `mcp-searxng` client sends `format=json`, which is rejected.

**Fix**: Add JSON (and other desired formats) to NixOS config:
```nix
services.searx.settings.search.formats = [ "html" "json" "csv" "rss" ];
```
Then `sudo nixos-rebuild switch`.

**NixOS config must include BOTH fixes for searxng MCP to work.**

---

### Debugging checklist for any SearXNG 403

1. `settings.server.limiter` → set `false` for local instances
2. `settings.search.formats` → must include `"json"` for API clients
3. Verify `/run/searx/settings.yml` is non-empty after rebuild (`sudo cat /run/searx/settings.yml`)
4. Confirm SearXNG was restarted after config change (check `pidof searxng-run` or `systemctl restart searx`)
5. Test directly: `curl -s "http://localhost:4001/search?q=test&format=json"` → should return JSON, not HTML 403 page
6. Adversarial testing with curl: even with browser-like headers (User-Agent, Accept, Sec-Fetch-*), the format check alone will cause 403 without the `search.formats` fix

---

### Instance details (this machine)

- URL: `http://localhost:4001`
- Secret key `keyboardcat` is NOT the cause of 403s
- NixOS config: `features/network/searx/default.nix` in dotfiles repo
