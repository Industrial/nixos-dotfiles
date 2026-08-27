---
name: hermes-plugin-development
description: >
  How to write, structure, and wire a Hermes Agent plugin in this dotfiles
  repo. Covers the full-plugin-with-tools pattern, Nix packaging, entry-point
  discovery, upstream skill delivery via fetchFromGitHub, and the hash workflow.
tags: [hermes, nix, plugin, python]
---

# Hermes Plugin Development

## Where plugins live

Plugins are NOT standalone features under `features/ai/<name>/`.
They live INSIDE the hermes-agent feature:

```
features/ai/hermes-agent/plugins/<plugin-name>/
```

> PITFALL: creating a plugin as a sibling feature (`features/ai/my-plugin/`)
> is wrong. Hermes will not discover it. The directory must be under
> `features/ai/hermes-agent/plugins/`.

## Plugin directory structure

```
plugins/<name>/
├── plugin.yaml                  # manifest
├── pyproject.toml               # declares hermes_agent.plugins entry point
├── package.nix                  # Nix derivation (buildPythonPackage)
├── README.md
└── <name_underscored>/          # Python package (name with hyphens → underscores)
    ├── __init__.py              # register(ctx) — entry point
    ├── schemas.py               # JSON-schema dicts the LLM sees
    └── tools.py                 # handler functions + hook handlers
```

## plugin.yaml

```yaml
name: my-plugin
version: 0.1.0
description: >
  One-line description.
provides_tools:
  - tool_name_one
provides_hooks:
  - on_session_start
```

## pyproject.toml — the critical entry point

```toml
[build-system]
requires = ["setuptools>=68", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "my-plugin"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = []

[project.entry-points."hermes_agent.plugins"]
my-plugin = "my_plugin_package"

[tool.setuptools.packages.find]
where = ["."]
include = ["my_plugin_package*"]
```

Hermes discovers plugins via `importlib.metadata` at session start using
the `hermes_agent.plugins` group. The key is the plugin name; the value is
the Python package containing `register()`.

## __init__.py — register(ctx)

```python
from . import schemas, tools

def register(ctx) -> None:
    # Register a tool:
    ctx.register_tool(
        name="my_tool",
        toolset="my_plugin",
        schema=schemas.MY_TOOL,
        handler=tools.my_tool,
    )
    # Register a hook:
    ctx.register_hook("on_session_start", tools.on_session_start)
```

Available hook events: `pre_tool_call`, `post_tool_call`, `pre_llm_call`,
`post_llm_call`, `on_session_start`, `on_session_end`.

Tool handler signature: `def handler(params: dict, **kwargs) -> str` — must
return a JSON string. Return `json.dumps({"success": False, "error": "..."})` 
on failure rather than raising.

Hook handler signature varies per event; always accept `**kwargs`.

## schemas.py shape

```python
MY_TOOL = {
    "name": "my_tool",
    "description": "What this tool does.",
    "parameters": {
        "type": "object",
        "properties": {
            "arg": {"type": "string", "description": "..."},
        },
        "required": ["arg"],
    },
}
```

## Nix wiring

### package.nix (plugin-side)

```nix
{ lib, python3Packages }:
python3Packages.buildPythonPackage {
  pname = "my-plugin";
  version = "0.1.0";
  src = ./.;
  pyproject = true;
  build-system = with python3Packages; [setuptools];
  dependencies = [];          # extend as tools.py gains imports
  pythonImportsCheck = ["my_plugin_package"];
  doCheck = false;
  meta = { ... };
}
```

### hermes-agent/package.nix (consumer-side)

Add `extraPlugins ? []` argument and wire it:

```nix
{ lib, python3Packages, fetchFromGitHub, extraPlugins ? [] }:
python3Packages.buildPythonApplication rec {
  ...
  propagatedBuildInputs = with python3Packages; [mcp]
    ++ extraPlugins;
}
```

### hermes-agent/default.nix (system-side)

```nix
environment.systemPackages = [
  (pkgs.callPackage ./package.nix {
    extraPlugins = [
      (pkgs.callPackage ./plugins/my-plugin/package.nix {})
    ];
  })
];
```

## Delivering upstream skills via fetchFromGitHub

When the plugin should expose a third-party skill repo (e.g. obra/superpowers)
as native Hermes skills under a namespace:

### 1. Get the pinned hash

```bash
# Get latest commit SHA from GitHub API or commits page
nix-prefetch-url --unpack https://github.com/<owner>/<repo>/archive/<rev>.tar.gz
nix hash convert --hash-algo sha256 --to sri <base32-output>
```

### 2. package.nix — fetchFromGitHub + postInstall symlink

```nix
let
  upstream-src = fetchFromGitHub {
    owner = "owner";
    repo  = "repo";
    rev   = "abcdef...";   # full commit SHA
    hash  = "sha256-...";  # SRI hash from above
  };
in
python3Packages.buildPythonPackage {
  ...
  postInstall = ''
    ln -s ${upstream-src}/skills \
      $out/${python3Packages.python.sitePackages}/my_plugin_package/skills
  '';
}
```

### 3. on_session_start hook — symlink into ~/.hermes/skills/<namespace>/

```python
import os
from pathlib import Path

_SKILLS_SRC = Path(__file__).parent / "skills"

def _link_skills(**kwargs) -> None:
    hermes_home = Path(os.environ.get("HERMES_HOME", Path.home() / ".hermes"))
    target = hermes_home / "skills" / "my-namespace"
    if not _SKILLS_SRC.exists():
        return
    (hermes_home / "skills").mkdir(parents=True, exist_ok=True)
    tmp = target.with_suffix(".tmp")
    if tmp.is_symlink(): tmp.unlink()
    tmp.symlink_to(_SKILLS_SRC)
    tmp.rename(target)   # atomic on POSIX
```

Register it: `ctx.register_hook("on_session_start", _link_skills)`

### Upgrading the pin

1. Get new rev from repo commits page
2. Run `nix-prefetch-url --unpack .../archive/<rev>.tar.gz`
3. Convert: `nix hash convert --hash-algo sha256 --to sri <base32>`
4. Update `rev` + `hash` in `package.nix`, bump version
5. `nixos-rebuild switch`

## References

- `references/hermes-plugin-api.md` — condensed Context7 extract of the
  Hermes plugin API (hooks, ctx methods, manifest fields)
