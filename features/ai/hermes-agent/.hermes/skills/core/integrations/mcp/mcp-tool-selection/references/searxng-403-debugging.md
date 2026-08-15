# SearXNG 403 Debugging Notes

## The `search.formats` Gotcha (2025-05-26)

### Default settings.yml (bundled with SearXNG)

The default `searx/settings.yml` shipped with SearXNG contains:
```yaml
search:
  formats: ["html"]
```

This means only HTML output is enabled by default. Any request with `?format=json` hits this check in `webapp.py`:

```python
# webapp.py lines 628-633
output_format = sxng_request.form.get('format', 'html')
if output_format not in OUTPUT_FORMATS:
    output_format = 'html'

if output_format not in settings['search']['formats']:
    flask.abort(403)
```

`OUTPUT_FORMATS` (from `settings_defaults.py`) is `['html', 'csv', 'json', 'rss']` -- so `json` passes the first check but fails the second when `settings['search']['formats']` is `['html']`.

### NixOS module behavior

The NixOS `services.searx` module generates `/run/searx/settings.yml` via `envsubst`. The template is a JSON file that gets merged with SearXNG's defaults when `use_default_settings: true` is set.

The merge logic (`update_settings` in `settings_loader.py`) does a dict-level merge, so `search.formats = ["json"]` in user config would **overwrite** (not append to) the default `["html"]`. You must list ALL desired formats.

### Working NixOS config

```nix
services.searx = {
  enable = true;
  settings = {
    server = {
      port = 4001;
      bind_address = "0.0.0.0";
      secret_key = "keyboardcat";
      limiter = false;        # disables bot detection (Cause 1)
    };
    search.formats = [ "html" "json" "csv" "rss" ];  # enables JSON API (Cause 2)
  };
};
```

### Verification steps

After `sudo nixos-rebuild switch`:

1. Check the generated settings:
   ```bash
   sudo cat /run/searx/settings.yml
   ```
   Should contain `"search":{"formats":["html","json","csv","rss"]}` (merged with defaults).

2. Test directly:
   ```bash
   curl -s "http://localhost:4001/search?q=test&format=json"
   ```
   Should return JSON, not an HTML 403 page.

3. Check the config endpoint:
   ```bash
   curl -s "http://localhost:4001/config" | python3 -c "import sys,json; d=json.load(sys.stdin); print('limiter:', d['server'].get('limiter')); print('formats:', d['search'].get('formats'))"
   ```
   Should show `limiter: false` and `formats: ['html', 'json', 'csv', 'rss']`.

### Key insight: two independent 403 mechanisms

| Mechanism | What blocks | Fix |
|-----------|-------------|-----|
| Bot detection limiter | All requests with non-browser headers | `server.limiter = false` |
| `search.formats` check | `/search` with non-html format param | Add formats to `search.formats` |

Both must be addressed for `mcp-searxng` to work. The limiter fix alone is insufficient.
