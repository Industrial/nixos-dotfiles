"""Install Cursor-side companion files for two-way Hermes/Cursor workflows."""

from __future__ import annotations

import json
import os
import shutil
from pathlib import Path
from typing import Any

from .config import HarnessConfig


RULE_TEXT = """---
description: Coordinate Cursor work with Hermes when Hermes Cursor Harness is available.
alwaysApply: false
---

When a task is being driven by Hermes, preserve Hermes as the outer runtime:
session state, approval policy, high-level intent, memory context, and final
transcript belong to Hermes. Use Cursor for repo-local coding work, tool calls,
analysis, edits, and shell execution.

If the Hermes Cursor Harness MCP server is available, use its read-only tools
to inspect Hermes session status, project context, and recent harness events
before making broad repo changes. These tools are context lookups, not approval
to edit files.

When useful, use the writeback tools to keep Hermes informed: append progress
with `hermes_cursor_append_event`, or create a reviewable handoff with
`hermes_cursor_propose`. These are not authority tools; Hermes must still
accept, reject, or complete proposals before they become task state, memory,
policy, or tool actions.

If `hermes_cursor_sdk_status` is available, it can confirm whether Hermes is
driving you through the official Cursor SDK bridge.

When Hermes supplied a permission mode, keep your work inside that mode. In
plan or ask mode, do not edit files. In edit mode, make focused repo changes
and report the exact files touched.
"""


SKILL_TEXT = """# Hermes Context

Use this skill when Cursor is operating as the inner coding runtime for a Hermes
session.

Before broad changes, check whether Hermes has provided:

- a project path or worktree boundary
- a permission mode
- a target branch or isolation policy
- relevant memory or prior task context
- a requested test command

Report back in terms Hermes can mirror cleanly:

- files changed
- commands run
- tests passed or failed
- unresolved risks
- follow-up actions

Prefer read-only Hermes MCP lookups for context:

- `hermes_cursor_status`
- `hermes_cursor_latest`
- `hermes_cursor_events`
- `hermes_cursor_project_context`
- `hermes_cursor_sdk_status`

Use writeback tools only for mirroring or handoff:

- `hermes_cursor_append_event` for progress, warnings, and results tied to a
  known harness session
- `hermes_cursor_propose` for memory updates, task updates, tool requests,
  questions, handoffs, or suggested Hermes actions that Hermes must review

Do not treat writeback as permission. In plan or ask mode, do not edit files
unless Hermes explicitly grants that mode.
"""


ENVIRONMENT_JSON = {
    "install": "",
    "terminals": [],
}


def install_cursor_companion(
    *,
    cfg: HarnessConfig,
    project_path: str | Path,
    force: bool = False,
) -> dict[str, Any]:
    """Install `.cursor` rules, skill, MCP config, and plugin skeleton."""

    project = Path(project_path).expanduser().resolve()
    if not project.exists() or not project.is_dir():
        raise ValueError(f"project_path must be an existing directory: {project}")

    cursor_dir = project / ".cursor"
    rules_dir = cursor_dir / "rules"
    skills_dir = cursor_dir / "skills"
    plugins_dir = cursor_dir / "plugins" / "hermes-harness"
    rules_dir.mkdir(parents=True, exist_ok=True)
    skills_dir.mkdir(parents=True, exist_ok=True)
    plugins_dir.mkdir(parents=True, exist_ok=True)

    written: list[str] = []
    written.append(str(_write_text(rules_dir / "hermes-harness.mdc", RULE_TEXT, force=force)))
    written.append(str(_write_text(skills_dir / "hermes-context.md", SKILL_TEXT, force=force)))
    written.append(str(_write_text(cursor_dir / "environment.json", json.dumps(ENVIRONMENT_JSON, indent=2) + "\n", force=False)))
    written.extend(str(path) for path in _write_plugin_skeleton(plugins_dir, force=force))
    written.append(str(_merge_mcp_config(cursor_dir / "mcp.json", cfg=cfg, force=force)))
    return {"success": True, "project_path": str(project), "written": sorted(set(written))}


def _write_text(path: Path, text: str, *, force: bool) -> Path:
    if path.exists() and not force:
        return path
    path.write_text(text, encoding="utf-8")
    return path


def _write_plugin_skeleton(target: Path, *, force: bool) -> list[Path]:
    files = {
        "index.json": json.dumps(
            {
                "name": "hermes-harness",
                "displayName": "Hermes Harness",
                "version": "0.1.1",
                "description": "Cursor-side companion for Hermes Cursor Harness.",
                "rules": ["rules/hermes-harness.mdc"],
                "skills": ["skills/hermes-context.md"],
                "mcps": {
                    "hermes-cursor-harness": {
                        "command": _mcp_command(),
                        "args": [],
                        "env": _mcp_env(),
                    }
                },
                "hooks": {},
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        "rules/hermes-harness.mdc": RULE_TEXT,
        "skills/hermes-context.md": SKILL_TEXT,
    }
    written: list[Path] = []
    for rel, text in files.items():
        path = target / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        written.append(_write_text(path, text, force=force))
    return written


def _merge_mcp_config(path: Path, *, cfg: HarnessConfig, force: bool) -> Path:
    data: dict[str, Any] = {}
    if path.exists():
        try:
            loaded = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                data = loaded
        except json.JSONDecodeError:
            if not force:
                raise ValueError(f"{path} is not valid JSON; pass force=true to replace it")
    servers = data.setdefault("mcpServers", {})
    if not isinstance(servers, dict):
        if not force:
            raise ValueError(f"{path} has non-object mcpServers; pass force=true to replace it")
        servers = {}
        data["mcpServers"] = servers
    servers["hermes-cursor-harness"] = {
        "command": _mcp_command(),
        "args": [],
        "env": _mcp_env(),
    }
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return path


def _mcp_command() -> str:
    wrapper = shutil.which("hermes-cursor-harness-mcp")
    if wrapper:
        return wrapper
    return "hermes-cursor-harness-mcp"


def _mcp_env() -> dict[str, str]:
    env: dict[str, str] = {}
    plugin_path = os.environ.get("HERMES_CURSOR_HARNESS_PLUGIN_PATH")
    if plugin_path:
        env["PYTHONPATH"] = plugin_path
    config_path = os.environ.get("HERMES_CURSOR_HARNESS_CONFIG")
    if config_path:
        env["HERMES_CURSOR_HARNESS_CONFIG"] = config_path
    return env
