"""Diagnostic bundle generation for Hermes Cursor Harness."""

from __future__ import annotations

import json
import os
import platform
import subprocess
import time
import zipfile
from pathlib import Path
from typing import Any

from .approval_queue import list_approval_requests
from .child_env import cursor_child_env
from .config import HarnessConfig, resolve_acp_command, resolve_sdk_command, resolve_stream_command
from .proposal_queue import list_cursor_proposals
from .provider_route import validate_provider_route
from .store import HarnessStore


REDACT_KEYS = ("KEY", "TOKEN", "SECRET", "PASSWORD")


def create_diagnostic_bundle(
    *,
    cfg: HarnessConfig,
    store: HarnessStore,
    output_dir: str | Path | None = None,
    hermes_root: str | Path | None = None,
    include_events: bool = True,
) -> dict[str, Any]:
    target_dir = Path(output_dir).expanduser() if output_dir else cfg.state_dir / "diagnostics"
    target_dir.mkdir(parents=True, exist_ok=True)
    bundle_path = target_dir / f"hermes-cursor-harness-diagnostics-{_safe_ts()}.zip"
    sessions = store.list_sessions()
    redacted_sessions = _redact_payload(sessions)
    payloads = {
        "summary.json": {
            "platform": platform.platform(),
            "python": platform.python_version(),
            "config": _redact_config(cfg),
            "cursor": _cursor_versions(cfg),
            "session_count": len(sessions),
            "latest_session": _redact_payload(_latest(sessions)),
            "background_agents": _redact_payload(store.list_background_agents()),
            "approvals": _redact_payload(list_approval_requests(cfg, include_resolved=True)),
            "proposals": _redact_payload(list_cursor_proposals(cfg, include_resolved=True)),
            "provider_route": validate_provider_route(hermes_root) if hermes_root else None,
        },
        "sessions.json": redacted_sessions,
        "environment.json": _redacted_environment(),
    }
    with zipfile.ZipFile(bundle_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for name, payload in payloads.items():
            zf.writestr(name, json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
        if include_events:
            for session in sessions:
                sid = str(session.get("harness_session_id") or "")
                if not sid:
                    continue
                zf.writestr(
                    f"events/{sid}.json",
                    json.dumps(_redact_payload(store.read_events(sid, limit=-1)), ensure_ascii=False, indent=2, sort_keys=True),
                )
    return {"success": True, "path": str(bundle_path), "session_count": len(sessions)}


def _cursor_versions(cfg: HarnessConfig) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for name, resolver in {"sdk": resolve_sdk_command, "stream": resolve_stream_command, "acp": resolve_acp_command}.items():
        try:
            command = resolver(cfg)
            if name == "sdk":
                result[name] = {"command": command}
                continue
            version_command = command[:-1] if name == "acp" and command[-1:] == ["acp"] else command
            proc = subprocess.run(
                version_command + ["--version"],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=10,
                check=False,
                env=cursor_child_env(include_test_controls=True),
            )
            result[name] = {"command": command, "returncode": proc.returncode, "stdout": proc.stdout.strip(), "stderr": proc.stderr.strip()}
        except Exception as exc:
            result[name] = {"error": str(exc)}
    return result


def _redact_config(cfg: HarnessConfig) -> dict[str, Any]:
    data = dict(cfg.__dict__)
    data["state_dir"] = str(cfg.state_dir)
    return {key: _redact_value(key, value) for key, value in data.items()}


def _redacted_environment() -> dict[str, str]:
    wanted = {key: value for key, value in os.environ.items() if key.startswith(("HERMES_", "CURSOR_"))}
    return {key: str(_redact_value(key, value)) for key, value in sorted(wanted.items())}


def _redact_value(key: str, value: Any) -> Any:
    upper = key.upper()
    if any(marker in upper for marker in REDACT_KEYS):
        return "[redacted]"
    if isinstance(value, list):
        return [_redact_value(key, item) for item in value]
    if isinstance(value, dict):
        return {k: _redact_value(k, v) for k, v in value.items()}
    return value


def _redact_payload(value: Any, key: str = "") -> Any:
    if isinstance(value, dict):
        return {str(k): _redact_payload(v, str(k)) for k, v in value.items()}
    if isinstance(value, list):
        return [_redact_payload(item, key) for item in value]
    return _redact_value(key, value)


def _latest(sessions: list[dict[str, Any]]) -> dict[str, Any] | None:
    if not sessions:
        return None
    return sorted(sessions, key=lambda item: int(item.get("updated_at_ms", 0)), reverse=True)[0]


def _safe_ts() -> str:
    return str(int(time.time() * 1000))
