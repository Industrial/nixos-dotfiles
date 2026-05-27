Dotfiles repo: /home/tom/.dotfiles (not /root/.dotfiles). Branch feat/lean-ctx-mcp-hermes-support. AI features live under features/ai/; each tool has package.nix + default.nix. hermes-agent/default.nix imports lean-ctx, roam-code, serena, context7. PR required (main is protected).
§
Hermes Agent tooling: There is NO web_search tool. For web/API research use curl via execute_code (e.g., GitHub API: api.github.com/search/repositories?q=...&sort=stars&order=desc). Use browser_navigate for page scraping. GitHub API rate-limits quickly (unauthenticated ~10 req/min); batch queries and add small delays between calls.
§
SearXNG instance: localhost:4001, NixOS-managed via services.searx. Config at features/network/searx/default.nix in dotfiles. Two independent 403 causes: (1) bot detection limiter blocks non-browser requests -- fix with server.limiter=false; (2) search.formats default is ["html"] only, so ?format=json gets 403 -- fix with search.formats=[html,json,csv,rss]. Both fixes required for mcp-searxng MCP client to work.
§
Hermes: plugins live under features/ai/hermes-agent/plugins/<name>/ (not features/ai/<name>/). `hermes skills` CLI manages skills from 9 registries (2,550 total). Skills use class-level names with references/, templates/, scripts/ support dirs.
§
Hermes: plugins live under features/ai/hermes-agent/plugins/<name>/ (not features/ai/<name>/). `hermes skills` CLI manages skills from 9 registries (2,550 total). Skills use class-level names with references/, templates/, scripts/ support dirs.
§
treefmt format:check: first run reformats in-place AND fails (fail-on-change=true + biome --write). Second run passes. Use `ci:format` (no fail-on-change) to format, then `format:check` to verify.
§
patch corruption: after a successful `patch` that removes lines, the file shifts. A second `patch` using pre-edit context can corrupt the file (e.g. duplicate function declarations). Recovery: `write_file` the entire corrected content. Prevention: `read_file` after each patch to get the new state before planning the next one.