"""Cursor model discovery helpers."""

from __future__ import annotations

import subprocess
from typing import Any

from .child_env import cursor_child_env
from .config import HarnessConfig, resolve_stream_command
from .sdk_runner import sdk_catalog_action


def list_cursor_models(cfg: HarnessConfig, timeout_sec: float = 45.0) -> dict[str, Any]:
    """Return Cursor Agent model IDs and display names."""

    try:
        sdk_result = sdk_catalog_action(cfg, "models", timeout_sec=timeout_sec)
    except Exception:
        sdk_result = {"success": False}
    if sdk_result.get("success"):
        return {
            "success": True,
            "source": "cursor_sdk",
            "models": parse_sdk_models(sdk_result.get("result") or []),
            "raw": sdk_result.get("result") or [],
            "error": None,
        }

    command = resolve_stream_command(cfg)
    try:
        proc = subprocess.run(
            command + ["models"],
            text=True,
            encoding="utf-8",
            errors="replace",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout_sec,
            check=False,
            env=cursor_child_env(include_test_controls=True),
        )
    except subprocess.TimeoutExpired as exc:
        return {
            "success": False,
            "command": command + ["models"],
            "models": [],
            "stdout": exc.stdout or "",
            "stderr": exc.stderr or "",
            "error": f"agent models timed out after {timeout_sec}s",
        }
    models = parse_models_output(proc.stdout)
    return {
        "success": proc.returncode == 0,
        "source": "cursor_agent_cli",
        "command": command + ["models"],
        "models": models,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
        "error": None if proc.returncode == 0 else f"agent models exited with {proc.returncode}",
    }


def parse_sdk_models(raw: Any) -> list[dict[str, Any]]:
    """Parse Cursor SDK model list items into a stable list."""

    if not isinstance(raw, list):
        return []
    models: list[dict[str, Any]] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        model_id = str(item.get("id") or "").strip()
        if not model_id:
            continue
        entry: dict[str, Any] = {
            "id": model_id,
            "label": str(item.get("displayName") or item.get("label") or model_id),
        }
        if item.get("description"):
            entry["description"] = str(item.get("description"))
        if item.get("parameters"):
            entry["parameters"] = item.get("parameters")
        if item.get("variants"):
            entry["variants"] = item.get("variants")
        models.append(entry)
    return models


def parse_models_output(text: str) -> list[dict[str, str]]:
    """Parse `agent models` output into a stable list."""

    models: list[dict[str, str]] = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.lower().startswith(("available models", "tip:")):
            continue
        if " - " not in stripped:
            continue
        model_id, label = stripped.split(" - ", 1)
        model_id = model_id.strip()
        label = label.strip()
        if model_id:
            models.append({"id": model_id, "label": label})
    return models
