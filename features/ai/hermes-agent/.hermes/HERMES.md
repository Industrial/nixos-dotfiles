# lean-ctx — Context Engineering Layer

PREFER lean-ctx MCP tools over native equivalents for token savings:

| PREFER | OVER | Why |
|--------|------|-----|
| `ctx_read(path, mode)` | `Read` / `cat` | Cached, 10 read modes, re-reads ~13 tokens |
| `ctx_shell(command)` | `Shell` / `bash` | Pattern compression for git/npm/cargo output |
| `ctx_search(pattern, path)` | `Grep` / `rg` | Compact search results |
| `ctx_tree(path, depth)` | `ls` / `find` | Compact directory maps |

- Native Edit/StrReplace stay unchanged. If Edit requires Read and Read is unavailable, use `ctx_edit(path, old_string, new_string)`.
- Write, Delete, Glob — use normally.

ctx_read modes: full|map|signatures|diff|task|reference|aggressive|entropy|lines:N-M. Auto-selects optimal mode.
Re-reads cost ~13 tokens (cached).

Available tools: ctx_overview, ctx_preload, ctx_dedup, ctx_compress, ctx_session, ctx_knowledge, ctx_semantic_search.
Multi-agent: ctx_agent(action=handoff|sync). Diary: ctx_agent(action=diary, category=discovery|decision|blocker|progress|insight).

<!-- lean-ctx-rules -->
<!-- version: 8 -->

lean-ctx shadow mode: native read/search/shell calls auto-route to ctx_* — no tool-mapping needed.
File editing → native Edit/StrReplace (lean-ctx only handles reads); if denied, use ctx_patch.
Exclusive tools (no native trigger): ctx_compose (understand code, call first), ctx_search(action=symbol) (exact symbol), ctx_search(action=semantic) (by meaning), ctx_callgraph (callers), ctx_knowledge / ctx_session (memory).
<!-- lean-ctx-compression -->
OUTPUT STYLE: concise
- Bullet points over paragraphs
- Skip filler words and hedging ("I think", "probably", "it seems")
- 1-sentence explanations max, then code/action
- No repeating what the user said
<!-- /lean-ctx-compression -->
<!-- /lean-ctx-rules -->