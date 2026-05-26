# id-hermes-superpowers

Superpowers agentic development workflows as native Hermes Agent tools.

Adapts the [obra/superpowers](https://github.com/obra/superpowers) skill
framework — brainstorming, plan writing, code review, systematic debugging,
TDD, and more — into first-class Hermes plugin tools.

## Status

Skeleton only. Tools and hooks are stubs pending workflow design decisions.

## Structure

```
id-hermes-superpowers/
├── plugin.yaml                      # Hermes plugin manifest
├── pyproject.toml                   # Python package + entry-point declaration
├── package.nix                      # Nix derivation (consumed by hermes-agent/default.nix)
├── README.md                        # This file
└── id_hermes_superpowers/
    ├── __init__.py                  # register(ctx) — wires tools and hooks
    ├── schemas.py                   # Tool schemas (JSON-schema dicts)
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

1. Add a handler function to `id_hermes_superpowers/tools.py`
2. Call `ctx.register_hook(event, handler)` in `__init__.py`
3. Add the hook name to `plugin.yaml` under `provides_hooks`

## Nix installation

The plugin is wired into the system via `hermes-agent/default.nix`.
Rebuild after any change:

```bash
nixos-rebuild switch
```
