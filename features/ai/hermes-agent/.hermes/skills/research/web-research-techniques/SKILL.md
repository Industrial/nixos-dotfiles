---
name: web-research-techniques
description: How to research topics on the internet using Hermes Agent's available tools. Covers the right tool for each research pattern, with recipes for GitHub API searches, web scraping, and synthesizing results.
---

# Web Research Techniques

## Available Tools for Research

| Pattern | Tool | Notes |
|---------|------|-------|
| GitHub API queries | `execute_code` + `curl` | Best for structured data (repos, stars, etc.) |
| Web page scraping | `browser_navigate` | For pages that need JS rendering |
| DuckDuckGo HTML | `execute_code` + `curl` to `html.duckduckgo.com` | Returns plain HTML, regex-parseable |
| SearxNG (self-hosted metasearch) | `execute_code` + `curl` to localhost:8080 | When searx service is enabled via features.ai.searxng |
| Context7 (library docs) | `mcp_context7_*` | Official docs for programming libraries |
| Roam code analysis | `mcp_roam_code_*` | Codebase intelligence for indexed repos |
| Roam code analysis | `mcp_roam_code_*` | Codebase intelligence for indexed repos |

## GitHub API Search Recipe

Search repos sorted by stars:

```bash
# Via execute_code, use curl:
curl -s "https://api.github.com/search/repositories?q=your+query+stars:>1000&sort=stars&order=desc&per_page=10"
```

Parse the JSON response for `full_name`, `stargazers_count`, `description`, `html_url`, `topics`.

**Rate limit**: unauthenticated ~10 req/min. Batch queries in a single `execute_code` call with small `time.sleep()` gaps.

## Multi-Pass Search Strategy

For comprehensive research (e.g., "find all agent frameworks"):
1. Run 3-5 different query strings in parallel in one `execute_code` call
2. Deduplicate by `full_name`
3. Sort combined results by stars
4. If rate-limited, wait and retry remaining queries

## Parsing DuckDuckGo HTML

```python
import re, subprocess
result = subprocess.run(["curl", "-s", "https://html.duckduckgo.com/html/?q=..."], capture_output=True, text=True)
titles = re.findall(r'<a rel="nofollow" class="result__a" href="([^"]+)"[^>]*>(.*?)</a>', result.stdout)
snippets = re.findall(r'<a rel="noopener" class="result__snippet"[^>]*>(.*?)</a>', result.stdout)
```

## Research Order: CLI-First Heuristic

When the topic involves a **CLI tool or binary** (suspected or confirmed), run the tool directly FIRST before searching other skill/registry systems:

1. `which <tool>` or `command -V <tool>` — check if it's on PATH and what kind of binary
2. `<tool> --help` — inspect the actual CLI surface
3. If it's a wrapper/alias, trace the real binary with `ls -la $(which <tool>)`
4. Only then fall back to: hermes skills search, web search, GitHub API, Context7, etc.

**Why**: The hermes skills registry indexes skill metadata — it won't tell you if `maestro` on PATH is actually a Bun binary under a misnamed symlink (NixOS package collision). The CLI itself reveals the ground truth.

**Applies to**: any named binary the user asks about. This is distinct from library research where "Context7 first" is the right order.

## Output Format (CLI)

The user is on a terminal. Use plain text, not markdown:
- No `**bold**` or `# headers` — use CAPS or indentation for structure
- No markdown tables — use aligned columns with spaces
- Keep lines narrow (~100 cols)

## Reference Files

- `references/agent-harnesses-and-skills.md` — Pre-researched catalog of agent harnesses, skills packs, and workflow frameworks sorted by GitHub stars (research from 2026-05-26). Check here first before re-searching this topic.
