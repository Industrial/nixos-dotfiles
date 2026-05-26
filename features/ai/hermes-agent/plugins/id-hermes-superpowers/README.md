# id-hermes-superpowers

Superpowers agentic development workflows as native Hermes Agent tools.

Adapts the [obra/superpowers](https://github.com/obra/superpowers) skill
framework — brainstorming, plan writing, code review, systematic debugging,
TDD, and more — into first-class Hermes plugin tools.

## How skills are delivered (Option B — fetchFromGitHub)

The upstream `obra/superpowers` repo is pinned in `package.nix` via
`fetchFromGitHub`.  During the Nix build the `skills/` tree is symlinked into
the Python package at `id_hermes_superpowers/skills/`.

At session start the `on_session_start` hook symlinks that Nix-store path into
`~/.hermes/skills/superpowers/`, making every upstream skill available natively:

```
superpowers:brainstorming
superpowers:dispatching-parallel-agents
superpowers:executing-plans
superpowers:finishing-a-development-branch
superpowers:receiving-code-review
superpowers:requesting-code-review
superpowers:subagent-driven-development
superpowers:systematic-debugging
superpowers:test-driven-development
superpowers:using-git-worktrees
superpowers:using-superpowers
superpowers:verification-before-completion
superpowers:writing-plans
superpowers:writing-skills
```

## Upgrading upstream skills

1. Get the new rev: https://github.com/obra/superpowers/commits/main
2. Prefetch the hash:
   ```bash
   nix-prefetch-url --unpack https://github.com/obra/superpowers/archive/<rev>.tar.gz
   nix hash convert --hash-algo sha256 --to sri <base32>
   ```
3. Update `rev` and `hash` in `package.nix`, bump `version` to match the
   upstream release tag.
4. Rebuild: `nixos-rebuild switch`

## Structure

```
id-hermes-superpowers/
├── plugin.yaml                      # Hermes plugin manifest
├── pyproject.toml                   # Python package + entry-point declaration
├── package.nix                      # Nix derivation — pins upstream repo via fetchFromGitHub
├── README.md                        # This file
└── id_hermes_superpowers/
    ├── __init__.py                  # register(ctx) — wires tools, hooks, and skills symlink
    ├── schemas.py                   # Tool schemas (JSON-schema dicts the LLM sees)
    └── tools.py                     # Tool and hook handler functions
```

## Adding a tool

1. Add a schema dict to `id_hermes_superpowers/schemas.py`
2. Add a handler function to `id_hermes_superpowers/tools.py`
3. Call `ctx.register_tool()` in `id_hermes_superpowers/__init__.py`
4. Add the tool name to `plugin.yaml` under `provides_tools`
5. Add any new Python deps to `dependencies` in `pyproject.toml` and
   `package.nix`

## Adding a hook

1. Add a handler to `id_hermes_superpowers/tools.py`
2. Call `ctx.register_hook(event, handler)` in `__init__.py`
3. Add the hook name to `plugin.yaml` under `provides_hooks`

## Nix installation

The plugin is wired into the system via `hermes-agent/default.nix`.
Rebuild after any change:

```bash
nixos-rebuild switch
```
