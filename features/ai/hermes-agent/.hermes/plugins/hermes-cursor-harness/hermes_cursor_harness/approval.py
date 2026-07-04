"""ACP permission selection and optional Hermes approval bridge command."""

from __future__ import annotations

import json
import subprocess
from typing import Any

from .child_env import cursor_child_env


def select_permission_option(
    *,
    options: list[dict[str, Any]],
    policy: str,
    params: dict[str, Any],
    trusted_readonly_mcp_tools: set[str],
    bridge_command: list[str] | None = None,
    bridge_timeout_sec: float = 120.0,
) -> tuple[str | None, str, str]:
    """Select an ACP permission option.

    Returns ``(option_id, source, reason)`` where source is one of
    ``trusted_mcp``, ``bridge``, or ``policy``.
    """

    if not options:
        return None, "policy", "no options"
    if _is_trusted_readonly_mcp_request(params, trusted_readonly_mcp_tools):
        return _first_option(options, ["allow_once"]), "trusted_mcp", "trusted read-only Hermes MCP tool"
    bridge = _ask_bridge(
        bridge_command=bridge_command or [],
        bridge_timeout_sec=bridge_timeout_sec,
        options=options,
        policy=policy,
        params=params,
    )
    if bridge is not None:
        return bridge, "bridge", "approval bridge selected option"
    return _policy_option(options, policy), "policy", f"selected by {policy} policy"


def _ask_bridge(
    *,
    bridge_command: list[str],
    bridge_timeout_sec: float,
    options: list[dict[str, Any]],
    policy: str,
    params: dict[str, Any],
) -> str | None:
    if not bridge_command:
        return None
    payload = {
        "policy": policy,
        "options": options,
        "request": params,
    }
    try:
        proc = subprocess.run(
            bridge_command,
            input=json.dumps(payload, ensure_ascii=False),
            text=True,
            encoding="utf-8",
            errors="replace",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=bridge_timeout_sec,
            check=False,
            env=cursor_child_env(include_cursor_credentials=False),
        )
    except Exception:
        return None
    if proc.returncode != 0 or not proc.stdout.strip():
        return None
    try:
        response = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return None
    option_id = response.get("optionId") or response.get("option_id") or response.get("selected_option")
    valid = {str(option.get("optionId")) for option in options if option.get("optionId")}
    if option_id and str(option_id) in valid:
        return str(option_id)
    if str(response.get("outcome") or "").lower() in {"cancel", "cancelled", "reject", "rejected"}:
        return _first_option(options, ["reject_once", "reject_always"])
    return None


def _policy_option(options: list[dict[str, Any]], policy: str) -> str | None:
    if policy == "full_access":
        preferred_kinds = ["allow_always", "allow_once"]
    elif policy == "edit":
        preferred_kinds = ["allow_once", "reject_once"]
    elif policy == "ask":
        preferred_kinds = ["reject_once", "reject_always"]
    else:
        preferred_kinds = ["reject_once", "reject_always"]
    return _first_option(options, preferred_kinds)


def _first_option(options: list[dict[str, Any]], preferred_kinds: list[str]) -> str | None:
    for kind in preferred_kinds:
        for option in options:
            if option.get("kind") == kind:
                return option.get("optionId")
    return options[0].get("optionId")


def _is_trusted_readonly_mcp_request(params: dict[str, Any] | None, trusted_readonly_mcp_tools: set[str]) -> bool:
    tool_call = (params or {}).get("toolCall") or {}
    title = str(tool_call.get("title") or "")
    if not title:
        return False
    prefix = "hermes-cursor-harness-"
    if not title.startswith(prefix):
        return False
    raw_name = title[len(prefix) :].split(":", 1)[0].strip()
    return raw_name in trusted_readonly_mcp_tools
