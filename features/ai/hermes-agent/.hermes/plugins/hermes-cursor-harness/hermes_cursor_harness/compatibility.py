"""Compatibility matrix storage for real Cursor/Hermes smoke results."""

from __future__ import annotations

import json
import subprocess
import time
from pathlib import Path
from typing import Any

from .child_env import cursor_child_env
from .config import HarnessConfig, resolve_stream_command
from .config_validator import environment_matrix
from .sdk_runner import sdk_status
from .smoke import run_smoke_suite
from .store import HarnessStore


def run_and_record_compatibility(
    *,
    cfg: HarnessConfig,
    store: HarnessStore,
    project: str | None = None,
    level: str = "quick",
    timeout_sec: float | None = None,
    include_cursor_mcp: bool = False,
    include_edit: bool = False,
    include_concurrency: bool = False,
    include_sdk: bool = False,
) -> dict[str, Any]:
    smoke = run_smoke_suite(
        cfg=cfg,
        store=store,
        project=project,
        level=level,
        timeout_sec=timeout_sec,
        include_cursor_mcp=include_cursor_mcp,
        include_edit=include_edit,
        include_concurrency=include_concurrency,
        include_sdk=include_sdk,
    )
    record = {
        "schema_version": 2,
        "timestamp_ms": int(time.time() * 1000),
        "success": bool(smoke.get("success")),
        "level": level,
        "requested_checks": {
            "include_cursor_mcp": include_cursor_mcp,
            "include_edit": include_edit,
            "include_concurrency": include_concurrency,
            "include_sdk": include_sdk,
        },
        "project": project,
        "environment": environment_matrix(cfg),
        "cursor_sdk": sdk_status(cfg, timeout_sec=20),
        "cursor_version": _cursor_version(cfg),
        "transport": cfg.transport,
        "security_profile": cfg.security_profile,
        "capabilities": _capabilities_from_smoke(smoke),
        "smoke": smoke,
    }
    records = load_compatibility_records(cfg)
    records.append(record)
    _matrix_path(cfg).write_text(json.dumps(records, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return {"success": bool(smoke.get("success")), "record": record, "matrix_path": str(_matrix_path(cfg))}


def load_compatibility_records(cfg: HarnessConfig) -> list[dict[str, Any]]:
    path = _matrix_path(cfg)
    if not path.exists():
        return []
    try:
        loaded = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return []
    return loaded if isinstance(loaded, list) else []


def _matrix_path(cfg: HarnessConfig) -> Path:
    cfg.state_dir.mkdir(parents=True, exist_ok=True)
    return cfg.state_dir / "compatibility_matrix.json"


def _cursor_version(cfg: HarnessConfig) -> str:
    try:
        command = resolve_stream_command(cfg)
        proc = subprocess.run(
            command + ["--version"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=10,
            check=False,
            env=cursor_child_env(include_test_controls=True),
        )
        return proc.stdout.strip() or proc.stderr.strip()
    except Exception as exc:
        return f"unknown: {exc}"


def _capabilities_from_smoke(smoke: dict[str, Any]) -> dict[str, Any]:
    checks = {item.get("name"): item for item in smoke.get("checks") or []}
    return {
        "sdk_command": _check_status(checks, "cursor.sdk_command"),
        "acp_command": _check_status(checks, "cursor.acp_command"),
        "stream_command": _check_status(checks, "cursor.stream_command"),
        "models": _check_status(checks, "real.models"),
        "stream_plan": _check_status(checks, "real.stream_plan"),
        "stream_resume": _check_status(checks, "real.stream_resume"),
        "acp_plan": _check_status(checks, "real.acp_plan"),
        "cursor_calls_mcp": _check_status(checks, "real.cursor_calls_mcp"),
        "bidirectional_backchannel": _check_status(checks, "mcp.bidirectional_backchannel"),
        "concurrency": _check_status(checks, "real.concurrency.isolated_sessions"),
    }


def _check_status(checks: dict[str, dict[str, Any]], name: str) -> str:
    return str((checks.get(name) or {}).get("status") or "not_run")
