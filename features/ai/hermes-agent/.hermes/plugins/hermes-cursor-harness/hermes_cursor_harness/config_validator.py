"""Structured configuration validation for Hermes Cursor Harness."""

from __future__ import annotations

import json
import platform
import sys
from pathlib import Path
from typing import Any

from .config import (
    WRITEBACK_MCP_TOOLS,
    default_config_path,
    find_executable,
    load_config,
    resolve_acp_command,
    resolve_sdk_command,
    resolve_stream_command,
)
from .child_env import cursor_child_env
from .credentials import background_key_status
from .security import apply_security_profile, available_security_profiles
from .sdk_runner import sdk_node_dir, sdk_status


def validate_config(
    path: str | Path | None = None,
    *,
    security_profile: str | None = None,
    project: str | None = None,
    include_sdk_status: bool = True,
) -> dict[str, Any]:
    """Validate config, command discovery, project aliases, and auth hints."""

    cfg_path = Path(path).expanduser() if path else default_config_path()
    checks: list[dict[str, Any]] = []
    raw = _read_raw_config(cfg_path, checks)
    cfg = None
    try:
        cfg = load_config(cfg_path)
        _add(checks, "config.load", "pass", f"Loaded {cfg_path}")
    except Exception as exc:
        _add(checks, "config.load", "error", str(exc))

    if cfg is None:
        return _result(cfg_path, checks, raw=raw, cfg=None)

    try:
        cfg = apply_security_profile(cfg, security_profile)
        if security_profile or cfg.security_profile:
            _add(checks, "security.profile", "pass", cfg.security_profile or "(none)")
    except Exception as exc:
        _add(checks, "security.profile", "error", str(exc))

    _validate_state_dir(cfg, checks)
    _validate_projects(cfg, checks, project=project)
    _validate_trusted_tools(cfg, checks)
    _validate_commands(cfg, checks)
    _validate_approval_bridge(cfg, checks)
    _validate_sdk(cfg, checks, include_sdk_status=include_sdk_status)
    _validate_background_key(checks)
    _validate_companion_wrapper(checks)
    _add(
        checks,
        "security.available_profiles",
        "info",
        sorted(available_security_profiles(cfg)),
    )
    return _result(cfg_path, checks, raw=raw, cfg=cfg)


def environment_matrix(cfg) -> dict[str, Any]:
    """Return stable environment facts for compatibility matrix records."""

    return {
        "platform": platform.platform(),
        "system": platform.system(),
        "machine": platform.machine(),
        "python": platform.python_version(),
        "python_executable": sys.executable,
        "node": _command_version(["node", "--version"]),
        "commands": {
            "sdk": _resolved_command_status(cfg, "sdk", resolve_sdk_command, version=False),
            "acp": _resolved_command_status(cfg, "acp", resolve_acp_command, version=True),
            "stream": _resolved_command_status(cfg, "stream", resolve_stream_command, version=True),
        },
        "cursor_api_key": background_key_status().public(),
        "sdk_node_dir": str(sdk_node_dir(cfg)),
    }


def _read_raw_config(path: Path, checks: list[dict[str, Any]]) -> dict[str, Any] | None:
    if not path.exists():
        _add(checks, "config.file", "warn", f"{path} does not exist; defaults and environment will be used")
        return None
    try:
        loaded = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        _add(checks, "config.json", "error", f"Invalid JSON: {exc}")
        return None
    if not isinstance(loaded, dict):
        _add(checks, "config.json", "error", "Config root must be a JSON object")
        return None
    _add(checks, "config.json", "pass", "JSON object")
    return loaded


def _validate_state_dir(cfg, checks: list[dict[str, Any]]) -> None:
    try:
        cfg.state_dir.mkdir(parents=True, exist_ok=True)
        test_path = cfg.state_dir / ".write-test"
        test_path.write_text("ok", encoding="utf-8")
        test_path.unlink()
        _add(checks, "state_dir.writable", "pass", str(cfg.state_dir))
    except Exception as exc:
        _add(checks, "state_dir.writable", "error", str(exc))


def _validate_projects(cfg, checks: list[dict[str, Any]], *, project: str | None) -> None:
    if not cfg.projects:
        _add(checks, "projects.aliases", "warn", "No project aliases configured")
    for name in sorted(cfg.projects):
        try:
            resolved = cfg.resolve_project(name)
            _add(checks, f"projects.{name}", "pass", str(resolved))
        except Exception as exc:
            _add(checks, f"projects.{name}", "error", str(exc))
    if project:
        try:
            _add(checks, "projects.requested", "pass", str(cfg.resolve_project(project)))
        except Exception as exc:
            _add(checks, "projects.requested", "error", str(exc))


def _validate_trusted_tools(cfg, checks: list[dict[str, Any]]) -> None:
    trusted = set(cfg.trusted_readonly_mcp_tools)
    unsafe = sorted(trusted.intersection(WRITEBACK_MCP_TOOLS))
    _add(
        checks,
        "mcp.trusted_readonly",
        "error" if unsafe else "pass",
        {"trusted": sorted(trusted), "unsafe_writeback_tools": unsafe},
    )


def _validate_commands(cfg, checks: list[dict[str, Any]]) -> None:
    for name, resolver, severity in (
        ("sdk", resolve_sdk_command, "warn"),
        ("acp", resolve_acp_command, "error"),
        ("stream", resolve_stream_command, "error"),
    ):
        try:
            command = resolver(cfg)
            _add(checks, f"commands.{name}", "pass", command)
        except Exception as exc:
            _add(checks, f"commands.{name}", severity, str(exc))


def _validate_sdk(cfg, checks: list[dict[str, Any]], *, include_sdk_status: bool) -> None:
    _add(checks, "sdk.node_dir", "info", str(sdk_node_dir(cfg)))
    if not include_sdk_status:
        return
    try:
        status = sdk_status(cfg, timeout_sec=20)
        detail = {key: value for key, value in status.items() if key not in {"rows"}}
        _add(checks, "sdk.status", "pass" if status.get("success") else "warn", detail)
    except Exception as exc:
        _add(checks, "sdk.status", "warn", str(exc))


def _validate_background_key(checks: list[dict[str, Any]]) -> None:
    status = background_key_status()
    _add(checks, "cursor_api_key", "pass" if status.available else "warn", status.public())


def _validate_companion_wrapper(checks: list[dict[str, Any]]) -> None:
    wrapper = find_executable("hermes-cursor-harness-mcp")
    _add(
        checks,
        "companion.mcp_wrapper",
        "pass" if wrapper else "warn",
        wrapper or "hermes-cursor-harness-mcp not found on PATH",
    )


def _validate_approval_bridge(cfg, checks: list[dict[str, Any]]) -> None:
    if not cfg.approval_bridge_command:
        _add(checks, "approval_bridge.command", "warn", "approval bridge disabled")
        return
    executable = str(cfg.approval_bridge_command[0])
    resolved = _resolve_command_executable(executable)
    _add(
        checks,
        "approval_bridge.command",
        "pass" if resolved else "warn",
        {"command": cfg.approval_bridge_command, "resolved": resolved},
    )


def _resolve_command_executable(executable: str) -> str | None:
    if "/" not in executable:
        return find_executable(executable)
    path = Path(executable).expanduser()
    return str(path) if path.is_file() else None


def _resolved_command_status(cfg, name: str, resolver, *, version: bool) -> dict[str, Any]:
    try:
        command = resolver(cfg)
    except Exception as exc:
        return {"available": False, "error": str(exc)}
    result: dict[str, Any] = {"available": True, "command": command}
    if version:
        result["version"] = _command_version(command + ["--version"])
    return result


def _command_version(command: list[str]) -> dict[str, Any]:
    try:
        import subprocess

        proc = subprocess.run(
            command,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=10,
            check=False,
            env=cursor_child_env(include_test_controls=True),
        )
        return {
            "returncode": proc.returncode,
            "stdout": proc.stdout.strip(),
            "stderr": proc.stderr.strip(),
        }
    except Exception as exc:
        return {"error": str(exc)}


def _add(checks: list[dict[str, Any]], name: str, status: str, detail: Any) -> None:
    checks.append({"name": name, "status": status, "detail": detail})


def _result(path: Path, checks: list[dict[str, Any]], *, raw: dict[str, Any] | None, cfg) -> dict[str, Any]:
    errors = [item for item in checks if item["status"] == "error"]
    warnings = [item for item in checks if item["status"] == "warn"]
    return {
        "success": not errors,
        "config_path": str(path),
        "summary": {
            "errors": len(errors),
            "warnings": len(warnings),
            "checks": len(checks),
        },
        "checks": checks,
        "config": _public_config(cfg) if cfg else None,
        "raw_keys": sorted(raw) if isinstance(raw, dict) else [],
    }


def _public_config(cfg) -> dict[str, Any]:
    return {
        "transport": cfg.transport,
        "sdk_runtime": cfg.sdk_runtime,
        "state_dir": str(cfg.state_dir),
        "projects": cfg.projects,
        "default_permission_policy": cfg.default_permission_policy,
        "trusted_readonly_mcp_tools": cfg.trusted_readonly_mcp_tools,
        "security_profile": cfg.security_profile,
        "allow_background_agents": cfg.allow_background_agents,
    }
