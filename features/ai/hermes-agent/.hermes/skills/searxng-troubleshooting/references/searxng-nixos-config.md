# SearXNG NixOS Configuration Reference

## Minimal working config for local MCP client access

```nix
services.searx = {
  enable = true;
  settings = {
    server = {
      port = 4001;
      bind_address = "0.0.0.0";
      secret_key = "change-me";
      limiter = false;
    };
    search.formats = [ "html" "json" "csv" "rss" ];
  };
};
```

## Key pitfalls

1. **Both `limiter = false` AND `search.formats` are required** for MCP clients.
2. **Default `search.formats` is `["html"]`** -- causes 403 on every `?format=json` request.
3. **Default `limiter`** probes HTTP headers and blocks non-browser requests.
4. **`secret_key`** is for Flask session signing only -- doesn't affect API access.
5. **List values in settings REPLACE rather than append** to defaults (deep merge behavior).

## Debugging commands

```bash
# Check running config
curl -s http://localhost:4001/config | python -m json.tool | grep -E '"(limiter|formats|port|bind)"'

# Test JSON search
curl -s "http://localhost:4001/search?q=test&format=json" | head -5

# Check settings file
sudo cat /run/searx/settings.yml

# Check logs
journalctl -u searx -n 50
```

## Two HTTP 403 causes

| Cause | Symptom | Fix |
|-------|---------|-----|
| Limiter | 403 on all /search regardless of headers | `server.limiter = false` |
| search.formats | 403 only on `?format=json/csv/rss` | `search.formats = [html,json,csv,rss]` |
