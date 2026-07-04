"""Self-test runner for the Hermes Cursor Harness."""

from __future__ import annotations

import json
import subprocess
import time
import tempfile
from pathlib import Path
from typing import Any

from .background import background_api_key
from .child_env import cursor_child_env
from .config import HarnessConfig, WRITEBACK_MCP_TOOLS, resolve_acp_command, resolve_sdk_command, resolve_stream_command
from .harness import run_turn
from .models import list_cursor_models
from .store import HarnessStore


def run_smoke_suite(
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
    """Run a bounded harness smoke suite and return structured results.

    Levels:
    - quick: configuration, command discovery, state store, and MCP/server shape.
    - real: quick checks plus live Cursor stream, resume, ACP, and model discovery.
    - full: real checks plus Cursor-calls-MCP and concurrency checks.
    """

    started = time.time()
    level = (level or "quick").lower()
    if level not in {"quick", "real", "full"}:
        raise ValueError("level must be quick, real, or full")
    checks: list[dict[str, Any]] = []

    _check(checks, "config.state_dir", bool(cfg.state_dir.exists()), str(cfg.state_dir))
    _check(checks, "config.trusted_readonly_mcp_tools", bool(cfg.trusted_readonly_mcp_tools), cfg.trusted_readonly_mcp_tools)
    _mcp_tools_shape_check(checks, cfg)
    _bidirectional_backchannel_check(checks, cfg)
    _optional_command_check(checks, "cursor.sdk_command", lambda: resolve_sdk_command(cfg))
    _command_check(checks, "cursor.acp_command", lambda: resolve_acp_command(cfg))
    _command_check(checks, "cursor.stream_command", lambda: resolve_stream_command(cfg))
    _check(checks, "store.sessions_readable", isinstance(store.list_sessions(), list), {"session_count": len(store.list_sessions())})
    _check(
        checks,
        "background.api_key",
        bool(background_api_key()),
        "CURSOR_BACKGROUND_API_KEY/CURSOR_API_KEY present" if background_api_key() else "not configured",
        skip_when_false=True,
    )

    if level in {"real", "full"}:
        if not project:
            _check(checks, "real.project", False, "project is required for real smoke")
        else:
            _models_check(checks, cfg)
            if include_sdk:
                _run_cursor_check(
                    checks,
                    cfg=cfg,
                    store=store,
                    project=project,
                    name="real.sdk_plan",
                    token="HCH_SDK_SMOKE_OK",
                    transport="sdk",
                    timeout_sec=timeout_sec,
                )
            stream_result = _run_cursor_check(
                checks,
                cfg=cfg,
                store=store,
                project=project,
                name="real.stream_plan",
                token="HCH_STREAM_SMOKE_OK",
                transport="stream",
                timeout_sec=timeout_sec,
            )
            if stream_result.get("success") and stream_result.get("harness_session_id"):
                _run_cursor_check(
                    checks,
                    cfg=cfg,
                    store=store,
                    project=project,
                    name="real.stream_resume",
                    token="HCH_STREAM_RESUME_OK",
                    transport="stream",
                    timeout_sec=timeout_sec,
                    harness_session_id=stream_result.get("harness_session_id"),
                )
            _run_cursor_check(
                checks,
                cfg=cfg,
                store=store,
                project=project,
                name="real.acp_plan",
                token="HCH_ACP_SMOKE_OK",
                transport="acp",
                timeout_sec=timeout_sec,
                prompt_prefix="Use the hermes-cursor-harness MCP server if available, then ",
            )

    if level == "full" or include_cursor_mcp:
        if project:
            _cursor_calls_mcp_check(checks, cfg=cfg, project=project, timeout_sec=timeout_sec)
        else:
            _check(checks, "real.cursor_calls_mcp", False, "project is required")

    if level == "full" or include_concurrency:
        if project:
            _concurrency_check(checks, cfg=cfg, store=store, project=project, timeout_sec=timeout_sec)
        else:
            _check(checks, "real.concurrency", False, "project is required")

    if include_edit:
        _temp_edit_check(checks, cfg=cfg, store=store, timeout_sec=timeout_sec)

    failed = [item for item in checks if item["status"] == "fail"]
    return {
        "success": not failed,
        "level": level,
        "duration_ms": int((time.time() - started) * 1000),
        "checks": checks,
        "failed": failed,
    }


def _check(
    checks: list[dict[str, Any]],
    name: str,
    ok: bool,
    detail: Any = None,
    *,
    skip_when_false: bool = False,
) -> None:
    checks.append(
        {
            "name": name,
            "status": "pass" if ok else ("skip" if skip_when_false else "fail"),
            "detail": detail,
        }
    )


def _command_check(checks: list[dict[str, Any]], name: str, resolver) -> None:
    try:
        command = resolver()
        _check(checks, name, True, command)
    except Exception as exc:
        _check(checks, name, False, str(exc))


def _optional_command_check(checks: list[dict[str, Any]], name: str, resolver) -> None:
    try:
        command = resolver()
        _check(checks, name, True, command)
    except Exception as exc:
        _check(checks, name, False, str(exc), skip_when_false=True)


def _models_check(checks: list[dict[str, Any]], cfg: HarnessConfig) -> None:
    result = list_cursor_models(cfg, timeout_sec=30)
    _check(checks, "real.models", bool(result.get("success")), {"count": len(result.get("models") or []), "error": result.get("error")})


def _mcp_tools_shape_check(checks: list[dict[str, Any]], cfg: HarnessConfig) -> None:
    from .mcp_server import TOOLS

    required_readonly = {
        "hermes_cursor_status",
        "hermes_cursor_latest",
        "hermes_cursor_events",
        "hermes_cursor_project_context",
        "hermes_cursor_sdk_status",
    }
    missing = sorted(required_readonly.union(WRITEBACK_MCP_TOOLS).difference(TOOLS))
    unsafe_trusted = sorted(set(cfg.trusted_readonly_mcp_tools).intersection(WRITEBACK_MCP_TOOLS))
    bad_readonly_hints = sorted(
        name
        for name in required_readonly
        if TOOLS.get(name, {}).get("annotations", {}).get("readOnlyHint") is not True
    )
    bad_writeback_hints = sorted(
        name
        for name in WRITEBACK_MCP_TOOLS
        if TOOLS.get(name, {}).get("annotations", {}).get("readOnlyHint") is not False
    )
    _check(
        checks,
        "mcp.tools_shape",
        not (missing or unsafe_trusted or bad_readonly_hints or bad_writeback_hints),
        {
            "missing": missing,
            "unsafe_trusted_readonly": unsafe_trusted,
            "bad_readonly_hints": bad_readonly_hints,
            "bad_writeback_hints": bad_writeback_hints,
        },
    )


def _bidirectional_backchannel_check(checks: list[dict[str, Any]], cfg: HarnessConfig) -> None:
    from dataclasses import replace

    from .mcp_server import McpServer
    from .proposal_queue import append_proposal_resolution_event, resolve_cursor_proposal
    from .store import SessionRecord

    try:
        with tempfile.TemporaryDirectory(prefix="hch-bidi-smoke-") as tmp:
            root = Path(tmp)
            project = root / "repo"
            project.mkdir()
            smoke_cfg = replace(cfg, state_dir=root / "state", projects={"smoke": str(project)})
            smoke_store = HarnessStore(smoke_cfg.state_dir)
            record = SessionRecord.new(
                project_path=str(project),
                transport="mcp",
                mode="plan",
                model=None,
                permission_policy="plan",
            )
            record.cursor_session_id = "cur_bidi_smoke"
            smoke_store.upsert(record)
            server = McpServer(cfg=smoke_cfg, store=smoke_store)
            event_payload = server.call_tool(
                "hermes_cursor_append_event",
                {
                    "harness_session_id": record.harness_session_id,
                    "event_type": "smoke",
                    "text": "Bidirectional smoke event",
                },
            )
            proposal_payload = server.call_tool(
                "hermes_cursor_propose",
                {
                    "harness_session_id": record.harness_session_id,
                    "title": "Bidirectional smoke proposal",
                    "body": "Verify proposal writeback and Hermes resolution.",
                    "source": "spoofed-source",
                },
            )
            proposal = proposal_payload["proposal"]
            resolved = resolve_cursor_proposal(smoke_cfg, proposal["id"], status="accepted", reason="Smoke accepted")
            resolution_event = append_proposal_resolution_event(smoke_cfg, resolved, source="hermes_smoke")
            events = smoke_store.read_events(record.harness_session_id, limit=-1)
            event_types = [item.get("type") for item in events]
            _check(
                checks,
                "mcp.bidirectional_backchannel",
                event_payload.get("success")
                and proposal.get("source") == "cursor_mcp"
                and resolved.get("status") == "accepted"
                and resolution_event is not None
                and event_types
                == [
                    "cursor_companion_event",
                    "cursor_companion_proposal",
                    "cursor_companion_proposal_resolution",
                ],
                {
                    "proposal_id": proposal.get("id"),
                    "proposal_source": proposal.get("source"),
                    "resolved_status": resolved.get("status"),
                    "event_types": event_types,
                },
            )
    except Exception as exc:
        _check(checks, "mcp.bidirectional_backchannel", False, str(exc))


def _run_cursor_check(
    checks: list[dict[str, Any]],
    *,
    cfg: HarnessConfig,
    store: HarnessStore,
    project: str,
    name: str,
    token: str,
    transport: str,
    timeout_sec: float | None,
    harness_session_id: str | None = None,
    prompt_prefix: str = "",
) -> dict[str, Any]:
    prompt = f"{prompt_prefix}Do not edit files. Include {token} in the final answer."
    try:
        result = run_turn(
            cfg=cfg,
            store=store,
            project=project,
            prompt=prompt,
            mode="plan",
            transport=transport,
            timeout_sec=timeout_sec or 120,
            new_session=not bool(harness_session_id),
            harness_session_id=harness_session_id,
        )
        text = str(result.get("text") or "")
        token_seen = token in text
        _check(
            checks,
            name,
            bool(result.get("success")) and bool(text.strip()) and token_seen,
            {
                "harness_session_id": result.get("harness_session_id"),
                "cursor_session_id": result.get("cursor_session_id"),
                "transport": result.get("transport"),
                "token_seen": token_seen,
                "text_present": bool(text.strip()),
                "file_hints": result.get("modified_files") or [],
                "error": result.get("error"),
            },
        )
        return result
    except Exception as exc:
        _check(checks, name, False, str(exc))
        return {"success": False, "error": str(exc)}


def _cursor_calls_mcp_check(checks: list[dict[str, Any]], *, cfg: HarnessConfig, project: str, timeout_sec: float | None) -> None:
    try:
        project_path = cfg.resolve_project(project)
        command = resolve_stream_command(cfg)
        token = "HCH_CURSOR_MCP_OK"
        argv = command + [
            "-p",
            "--trust",
            "--force",
            "--approve-mcps",
            "--output-format",
            "stream-json",
            f"Use the hermes-cursor-harness MCP server to inspect latest session. Do not edit files. Include {token}.",
        ]
        proc = subprocess.run(
            argv,
            cwd=str(project_path),
            text=True,
            encoding="utf-8",
            errors="replace",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout_sec or 120,
            check=False,
            env=cursor_child_env(include_test_controls=True),
        )
        tool_seen = "hermes_cursor_" in proc.stdout
        token_seen = token in proc.stdout
        _check(
            checks,
            "real.cursor_calls_mcp",
            proc.returncode == 0 and tool_seen and token_seen,
            {"returncode": proc.returncode, "tool_seen": tool_seen, "token_seen": token_seen, "stderr": proc.stderr[-500:]},
        )
    except Exception as exc:
        _check(checks, "real.cursor_calls_mcp", False, str(exc))


def _concurrency_check(
    checks: list[dict[str, Any]],
    *,
    cfg: HarnessConfig,
    store: HarnessStore,
    project: str,
    timeout_sec: float | None,
) -> None:
    first = _run_cursor_check(
        checks,
        cfg=cfg,
        store=store,
        project=project,
        name="real.concurrency.first",
        token="HCH_CONCURRENCY_A",
        transport="stream",
        timeout_sec=timeout_sec,
    )
    second = _run_cursor_check(
        checks,
        cfg=cfg,
        store=store,
        project=project,
        name="real.concurrency.second",
        token="HCH_CONCURRENCY_B",
        transport="stream",
        timeout_sec=timeout_sec,
    )
    _check(
        checks,
        "real.concurrency.isolated_sessions",
        bool(first.get("harness_session_id")) and first.get("harness_session_id") != second.get("harness_session_id"),
        {"first": first.get("harness_session_id"), "second": second.get("harness_session_id")},
    )


def _temp_edit_check(checks: list[dict[str, Any]], *, cfg: HarnessConfig, store: HarnessStore, timeout_sec: float | None) -> None:
    root = cfg.state_dir / "smoke-workspaces" / f"edit-{int(time.time() * 1000)}"
    root.mkdir(parents=True, exist_ok=True)
    (root / "README.md").write_text("# Harness Edit Smoke\n", encoding="utf-8")
    try:
        result = run_turn(
            cfg=cfg,
            store=store,
            project=str(root),
            prompt="Create or overwrite SMOKE_EDIT.txt with exactly HCH_EDIT_SMOKE_OK and no other changes.",
            mode="edit",
            transport="stream",
            timeout_sec=timeout_sec or 180,
            new_session=True,
        )
        target = root / "SMOKE_EDIT.txt"
        content_ok = target.exists() and "HCH_EDIT_SMOKE_OK" in target.read_text(encoding="utf-8", errors="replace")
        _check(
            checks,
            "real.temp_edit",
            bool(result.get("success")) and content_ok,
            {
                "workspace": str(root),
                "harness_session_id": result.get("harness_session_id"),
                "modified_files": result.get("modified_files") or [],
                "content_ok": content_ok,
                "error": result.get("error"),
            },
        )
    except Exception as exc:
        _check(checks, "real.temp_edit", False, {"workspace": str(root), "error": str(exc)})


def summary_text(result: dict[str, Any]) -> str:
    lines = [f"Hermes Cursor Harness smoke: {'PASS' if result.get('success') else 'FAIL'}"]
    for item in result.get("checks") or []:
        lines.append(f"- {item.get('status', 'unknown').upper()} {item.get('name')}: {item.get('detail')}")
    return "\n".join(lines)
