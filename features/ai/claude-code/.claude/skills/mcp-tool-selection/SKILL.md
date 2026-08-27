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

## CLI Tools vs MCP Servers

**MCP servers** register in `~/.hermes/config.yaml` under `mcp_servers` and run as long-lived daemon clients. Examples: `lean-ctx`, `roam-code`, `context7`, `serena`, `searxng`.

**CLI tools** (e.g. `cargo`, `pytest`) are invoked per-task via `terminal()` — they have NO entry in `mcp_servers` regardless of capability.

**maestro is NOT CLI-only** — it ships `maestro mcp serve` which starts the stdio MCP server. See [maestro MCP section](#maestro-mcp-server) below.

When a user asks why a tool "isn't registering in Hermes MCP," check:
1. Does it have an `mcp_servers` entry in `~/.hermes/config.yaml`? If not, it's not an MCP server.
2. Read its package.nix — look for *"not applicable"* as explicit confirmation it's CLI-only. If not present, verify the binary actually has the MCP subcommand (see [Diagnosing a Broken Binary](#diagnosing-a-broken-binary-on-nixos), below).
3. The package.nix `sha256` is authoritative for downloads but NOT for the nix store — a corrupted store entry can contain the wrong binary despite a valid hash.

Quick diagnosis table:

| Check | MCP Server | CLI Tool |
|-------|-----------|---------|
| Entry in `mcp_servers` config | ✅ | ❌ |
| Long-running daemon | ✅ | ❌ |
| Exposes protocol tools | ✅ | ❌ |
| Examples | `roam-code`, `serena`, `lean-ctx` | `cargo` |

## Usage Rules
- Always run **roam-code** pre‑flight before making any structural edit with **serena**.
- Use **context7** when the task involves third‑party library APIs.
- Compress large intermediate outputs with **lean‑ctx** when the context budget exceeds ~50%.
- **serena** tools are write‑only; do not replace them with `execute_shell_command`.
- Use **searxng** for web search tasks when available.

## Adding a New MCP Server to Hermes

**1. Find the server startup command**
```bash
<tool> --help
<tool> mcp --help       # common subcommand
<tool> mcp serve --help
```

**2. Register in `~/.hermes/config.yaml`**
```yaml
mcp_servers:
  # ... existing servers ...
  <name>:
    command: <executable>
    args: ["mcp", "serve"]   # or appropriate subcommand
    enabled: true
```

**3. Restart Hermes Agent** — the new server will be detected on next start.

**4. Verify** with `hermes tools` or by checking if new tools appear.

## Diagnosing a Broken Binary on NixOS

**Pattern**: `which <tool>` points to a nix store path, but the binary behaves wrong (wrong version output, missing expected subcommands, output doesn't match the project name).

**Step-by-step diagnosis**:
```
# 1. Identify the store path
which <tool>
# → /nix/store/...-package-version/bin/tool

# 2. Check what binary is actually in the store
strings /nix/store/.../bin/tool | grep -i "project-name\|expected-subcommand"
file /nix/store/.../bin/tool
ldd /nix/store/.../bin/tool   # for dynamically linked binaries

# 3. Compare store binary hash vs package.nix hash
sha256sum /nix/store/.../bin/tool
# Compare against sha256 value in package.nix

# 4. Download the actual release and compute correct hash
curl -L "https://github.com/org/repo/releases/download/vX.Y.Z/tool-linux-x64" -o /tmp/tool-test
nix hash file --sri /tmp/tool-test
# Use the reported SRI hash in package.nix

# 5. If store binary is wrong (different project), fix:
#    a. Update sha256 in package.nix (or use lib.fakeHash + nix-build to discover it)
#    b. Rebuild: nix build . -A <package>  (or nixos-rebuild for system packages)
#    c. The content-addressed store ensures the correct binary gets a new path
```

**maestro case study** (2026-05-26):
- `maestro --version` returned `bun 1.3.11`; `--help` was Bun usage text
- `fetchurl` had the correct GitHub release (`sha256` matched the API digest)
- **Root cause**: `autoPatchelfHook` rewrote the Bun-compiled standalone ELF; stdenv fixup made it worse
- **Fix**: in `features/ai/maestro/package.nix`, use `patchelf --set-interpreter` only, drop `autoPatchelfHook`, set `dontShrinkRpath` + `dontStrip`, then `nixos-rebuild`

**Key insight**: wrong `sha256` is not the only failure mode — patchelf can turn a correct download into a runnable `bun` binary. Compare `$out/bin/maestro` against `/tmp/maestro-linux-x64` after build.

### Failure mode: stale .drv derivation cache

When a rebuild fails with a hash mismatch AND the "got" hash matches your package.nix but the "specified" hash in the error is different:

```
specified: sha256-eADx2L9azOybQOPqisoBYgmK7aZRBrGpz/ORiBuMzBY=
   got:    sha256-6v4wIJ5vZ2f4u2JgDm+T8dYApcfqQmfYOrwuWJgHk/w=
```

...but your package.nix already has the correct hash (`7800f1d8...`). This means the **derivation cache** (`/nix/store/<hash>-<name>.drv`) is stale — it was created before you updated the hash. The .drv file holds cached input hashes and is not automatically invalidated when package.nix changes.

Fix: `sudo rm /nix/store/<hash>-<name>.drv` using the path from the error output, then retry the rebuild. Alternative: `sudo nixos-rebuild switch --refresh` forces re-evaluation of all derivation inputs.

## maestro MCP Server

maestro v0.106.1+ ships `maestro mcp serve` which starts the stdio MCP server.

For mission creation, task decompose, and evidence recording patterns via MCP
tools, see `maestro-mcp-patterns` — it covers pitfalls only visible when using
`mcp_maestro_*` tools (not the CLI): the spec frontmatter requirement, the
bare+decompose path, directory prerequisites, and contract gotchas.

**Prerequisite**: `maestro --version` must NOT show `bun`. If it shows `bun`, rebuild with the interpreter-only packaging pattern (see [Diagnosing a Broken Binary](#diagnosing-a-broken-binary-on-nixos)).

**Registration** (`~/.hermes/config.yaml`):
```yaml
mcp_servers:
  maestro:
    command: maestro
    args: ["mcp", "serve"]
    enabled: true
```

## Multi-root sessions: MCP servers bind to the LAUNCH project root

MCP servers in this setup resolve project state (lean-ctx index/jail, maestro
`.maestro/` store) relative to the directory where Hermes STARTED, not the
per-call `workdir`/`cwd`. When a session moves to a second repo:

- lean-ctx `ctx_shell`/`cwd` rejects paths outside the launch root ("path
  escapes project root"). Fix is additive config (`extra_roots` in
  `~/.config/lean-ctx/config.toml`, shown by `lean-ctx doctor`); until then,
  use plain terminal/read_file for the second repo.
- Maestro MCP reads return TASK_NOT_FOUND for ids that exist in the second
  repo's own `.maestro/` — see `maestro-mcp-patterns` for the direct-file
  fallback procedure. Never write evidence through a wrong-root server.
- Do NOT encode "tool X cannot work cross-repo" from one occurrence: both
  behaviors are configuration-state, with additive fixes.

---

## SearXNG Troubleshooting

### Symptom: MCP calls return HTTP 403 "Authentication required or IP blocked"
There are **two independent causes** of 403 on SearXNG's `/search` endpoint. Check both.

### Cause 1: Bot detection limiter

SearXNG's limiter blocks non-browser requests via `http_user_agent`, `http_accept`, and `http_sec_fetch` filters.
**Fix**: Disable the limiter in NixOS config:
```nix
services.searx.settings.server.limiter = false;
```
Then `sudo nixos-rebuild switch`. Safe for local/internal instances.

### Cause 2: `search.formats` doesn't include `json`

The `/search` handler checks `settings.search.formats` and returns 403 if the requested format isn't listed. The default is `["html"]` only. The `mcp-searxng` client sends `format=json`, which is rejected.

**Fix**: Add JSON (and other desired formats) to NixOS config:
```nix
services.searx.settings.search.formats = [ "html" "json" "csv" "rss" ];
```
Then `sudo nixos-rebuild switch`.
**NixOS config must include BOTH fixes for searxng MCP to work.**

### Debugging checklist for any SearXNG 403

1. `settings.server.limiter` → set `false` for local instances
2. `settings.search.formats` → must include `"json"` for API clients
3. Verify `/run/searx/settings.yml` is non-empty after rebuild
4. Confirm SearXNG was restarted after config change
5. Test directly: `curl -s "http://localhost:4001/search?q=test&format=json"` → should return JSON, not HTML 403 page
6. Even with browser-like headers (User-Agent, Accept, Sec-Fetch-*), the format check alone will cause 403 without the `search.formats` fix

### Instance details (this machine)

- URL: `http://localhost:4001`
- Secret key `keyboardcat` is NOT the cause of 403s
- NixOS config: `features/network/searx/default.nix` in dotfiles repo