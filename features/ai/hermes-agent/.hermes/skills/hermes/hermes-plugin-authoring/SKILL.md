---
name: hermes-plugin-authoring
description: >
  How to write, wire, and Nix-package a Hermes Agent plugin in the
  /home/tom/.dotfiles repo. Covers plugin structure, the register(ctx) API,
  tool/hook registration, the hermes_agent.plugins entry point, Nix
  derivation pattern, and how to extend hermes-agent/default.nix and
  package.nix for new plugins.
tags: [hermes, nix, plugin, python]
---

# Hermes Plugin Authoring

## Where plugins live

Plugins are Python packages under:

    features/ai/hermes-agent/plugins/<plugin-name>/

NOT under features/ai/ directly. NOT as standalone MCP server features.
MCP servers are a separate surface (features/ai/<tool>/); plugins may
optionally wrap an MCP server but are not themselves MCP servers.

## Required file structure

    plugins/<plugin-name>/
    ├── plugin.yaml                  # Hermes manifest
    ├── pyproject.toml               # Python package + entry-point declaration
    ├── package.nix                  # Nix derivation
    ├── README.md                    # how to add tools/hooks
    └── <python_package>/            # snake_case version of plugin-name
        ├── __init__.py              # register(ctx) — all wiring happens here
        ├── schemas.py               # tool schemas (JSON-schema dicts)
        └── tools.py                 # handler functions + hook functions

## plugin.yaml

```yaml
name: my-plugin
version: 0.1.0
description: Short description
provides_tools: []      # fill in as tools are added
provides_hooks: []      # fill in as hooks are added
```

## pyproject.toml — critical section

The entry-point key is how Hermes discovers the plugin via importlib.metadata:

```toml
[project.entry-points."hermes_agent.plugins"]
my-plugin = "my_python_package"
```

Full minimal pyproject.toml:

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
my-plugin = "my_python_package"

[tool.setuptools.packages.find]
where = ["."]
include = ["my_python_package*"]
```

## __init__.py — register(ctx)

```python
from . import schemas, tools
import logging
logger = logging.getLogger(__name__)

def register(ctx) -> None:
    # Tools:
    ctx.register_tool(
        name="my_tool",
        toolset="my_plugin",
        schema=schemas.MY_TOOL,
        handler=tools.my_tool,
    )
    # Hooks (available: pre_tool_call, post_tool_call,
    #         pre_llm_call, post_llm_call,
    #         on_session_start, on_session_end):
    ctx.register_hook("on_session_start", tools.on_session_start)
```

## schemas.py — tool schema shape

```python
MY_TOOL = {
    "name": "my_tool",
    "description": "What the LLM sees.",
    "parameters": {
        "type": "object",
        "properties": {
            "arg": {"type": "string", "description": "..."},
        },
        "required": ["arg"],
    },
}
```

## tools.py — handler shape

```python
import json, logging
logger = logging.getLogger(__name__)

def my_tool(params: dict, **kwargs) -> str:
    # kwargs: task_id, session, agent, etc.
    arg = params.get("arg", "")
    # ... logic ...
    return json.dumps({"success": True, "result": arg})

# On error — never raise; return error JSON:
#   return json.dumps({"success": False, "error": str(e)})
```

## package.nix (Python plugin)

```nix
{ lib, python3Packages }:
python3Packages.buildPythonPackage {
  pname = "my-plugin";
  version = "0.1.0";
  src = ./.;
  pyproject = true;
  build-system = with python3Packages; [setuptools];
  dependencies = [];          # extend as tools.py gains imports
  pythonImportsCheck = ["my_python_package"];
  doCheck = false;
  meta = {
    description = "Short description";
    homepage = "...";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
```

## Wiring into hermes-agent/default.nix + package.nix

### default.nix — pass extraPlugins

```nix
environment.systemPackages = [
  (pkgs.callPackage ./package.nix {
    extraPlugins = [
      (pkgs.callPackage ./plugins/my-plugin/package.nix {})
    ];
  })
];
```

### package.nix — accept and propagate extraPlugins

Add to the function arguments:

```nix
extraPlugins ? [],
```

Wire into propagatedBuildInputs:

```nix
propagatedBuildInputs = with python3Packages; [mcp]
  ++ extraPlugins;
```

This puts the plugin's site-packages on PYTHONPATH so importlib.metadata
finds the hermes_agent.plugins entry point at session start.

## Workflow: research before build

Tom's preferred sequence:
1. Use Context7 MCP to look up docs (mcp_context7_resolve_library_id →
   mcp_context7_query_docs) for the upstream project.
2. Discuss findings before writing any code.
3. When "implement" is said — write ALL files in one complete pass.

## Pitfalls

- Do NOT place plugins under features/ai/ at top level — that is for MCP
  server features (lean-ctx, roam-code, serena, context7). Plugins belong
  under features/ai/hermes-agent/plugins/.
- Do NOT confuse Hermes plugins (Python, register(ctx)) with Hermes skills
  (Markdown SKILL.md files in ~/.hermes/skills/). They are different surfaces.
- plugin.yaml provides_tools and provides_hooks must be updated alongside
  __init__.py or Hermes may warn about undeclared registrations.
- src = ./. in package.nix works because the plugin is in-tree. No
  fetchFromGitHub needed for local plugins.
- extraPlugins propagation is what makes importlib.metadata discovery work —
  without it the entry point is not on PYTHONPATH at runtime.
- Prebuilt release binaries (e.g. from GitHub releases) are often dynamically
  linked and fail on NixOS with "Could not start dynamically linked executable".
  Always add `autoPatchelfHook` to buildInputs when packaging a fetchurl'd binary.
  See references/prebuilt-binary-packaging.md for the exact pattern.

See also: references/hermes-plugin-api.md, references/prebuilt-binary-packaging.md