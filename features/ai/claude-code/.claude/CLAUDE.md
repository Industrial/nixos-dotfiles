# lean-ctx — Context Engineering Layer
<!-- lean-ctx-rules-v8 -->

CRITICAL: ALWAYS use lean-ctx MCP tools instead of native equivalents. This is NOT optional.

| ALWAYS USE | NEVER USE | Why |
|------------|-----------|-----|
| `ctx_read(path)` | `Read` / `cat` / `head` / `tail` | Cached, 8 compression modes, re-reads ~13 tokens |
| `ctx_shell(command)` | `Shell` / `bash` / terminal | Pattern compression for git/npm/cargo output |
| `ctx_search(pattern, path)` | `Grep` / `rg` | Compact, token-efficient results |
| `ctx_tree(path, depth)` | `ls` / `find` | Compact directory maps |

Compatibility: ctx_read replaces READ operations only. Your native Edit/Write/StrReplace tools remain unchanged — keep using them for editing. If your rules say "use Edit or Write tools only", that is compatible: lean-ctx only replaces how you READ files, not how you EDIT them.

If Edit requires native Read and Read is unavailable, use `ctx_edit(path, old_string, new_string)` instead.
Write, Delete, Glob → use normally. NEVER loop on Edit failures — switch to ctx_edit immediately.
<!-- /lean-ctx -->
