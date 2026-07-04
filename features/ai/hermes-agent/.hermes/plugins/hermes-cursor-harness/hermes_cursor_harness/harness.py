"""High-level harness orchestration."""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path
from typing import Any

from .acp_client import run_acp_turn
from .config import HarnessConfig, PERMISSION_POLICIES
from .sdk_runner import run_sdk_turn
from .security import ensure_transport_allowed
from .store import HarnessStore, SessionRecord
from .stream_runner import run_stream_turn


def run_turn(
    *,
    cfg: HarnessConfig,
    store: HarnessStore,
    project: str,
    prompt: str,
    mode: str | None = None,
    model: str | None = None,
    hermes_session_id: str | None = None,
    harness_session_id: str | None = None,
    new_session: bool = False,
    transport: str | None = None,
    timeout_sec: float | None = None,
    event_callback: Callable[[dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    """Run a Cursor turn with SDK first, falling back to ACP and stream-json in auto mode."""

    if not prompt or not prompt.strip():
        raise ValueError("prompt is required")
    if timeout_sec is not None and timeout_sec <= 0:
        raise ValueError("timeout_sec must be positive")

    project_path = cfg.resolve_project(project)
    permission_policy = (mode or cfg.default_permission_policy).lower()
    if permission_policy not in PERMISSION_POLICIES:
        raise ValueError(f"mode must be one of {sorted(PERMISSION_POLICIES)}")
    chosen_transport = (transport or cfg.transport).lower()
    if chosen_transport not in {"auto", "sdk", "acp", "stream"}:
        raise ValueError("transport must be auto, sdk, acp, or stream")
    ensure_transport_allowed(cfg, chosen_transport)

    record = _resolve_record(
        cfg=cfg,
        store=store,
        project_path=project_path,
        harness_session_id=harness_session_id,
        new_session=new_session,
        transport="sdk" if chosen_transport == "auto" else chosen_transport,
        mode=permission_policy,
        model=model or cfg.default_model,
        hermes_session_id=hermes_session_id,
    )

    if chosen_transport == "stream":
        return run_stream_turn(
            cfg=cfg,
            store=store,
            record=record,
            prompt=prompt,
            timeout_sec=timeout_sec,
            event_callback=event_callback,
        )
    if chosen_transport == "sdk":
        return run_sdk_turn(
            cfg=cfg,
            store=store,
            record=record,
            prompt=prompt,
            timeout_sec=timeout_sec,
            event_callback=event_callback,
        )
    if chosen_transport == "acp":
        return run_acp_turn(
            cfg=cfg,
            store=store,
            record=record,
            prompt=prompt,
            timeout_sec=timeout_sec,
            event_callback=event_callback,
        )

    fallback_errors: list[str] = []
    try:
        sdk_result = run_sdk_turn(
            cfg=cfg,
            store=store,
            record=record,
            prompt=prompt,
            timeout_sec=timeout_sec,
            event_callback=event_callback,
        )
        if sdk_result.get("success"):
            return sdk_result
        raise RuntimeError(str(sdk_result.get("error") or "Cursor SDK transport failed before session start"))
    except Exception as exc:
        fallback_errors.append(f"SDK failed, falling back to ACP: {exc}")
        record.transport = "acp"
        record.last_error = fallback_errors[-1]
        store.upsert(record)

    try:
        acp_result = run_acp_turn(
            cfg=cfg,
            store=store,
            record=record,
            prompt=prompt,
            timeout_sec=timeout_sec,
            event_callback=event_callback,
        )
        if fallback_errors:
            acp_result["fallback_reason"] = "; ".join(fallback_errors)
        return acp_result
    except Exception as exc:
        fallback_errors.append(f"ACP failed, falling back to stream-json: {exc}")
        record.transport = "stream"
        record.last_error = fallback_errors[-1]
        store.upsert(record)
        result = run_stream_turn(
            cfg=cfg,
            store=store,
            record=record,
            prompt=prompt,
            timeout_sec=timeout_sec,
            event_callback=event_callback,
        )
        result["fallback_reason"] = "; ".join(fallback_errors)
        return result


def _resolve_record(
    *,
    cfg: HarnessConfig,
    store: HarnessStore,
    project_path: Path,
    harness_session_id: str | None,
    new_session: bool,
    transport: str,
    mode: str,
    model: str | None,
    hermes_session_id: str | None,
) -> SessionRecord:
    record: SessionRecord | None = None
    if harness_session_id and not new_session:
        record = store.get(harness_session_id)
        if record is None:
            raise ValueError(f"unknown harness_session_id {harness_session_id}")
        if Path(record.project_path) != project_path:
            raise ValueError(
                f"harness_session_id {harness_session_id} belongs to {record.project_path}, not {project_path}"
            )
    elif not new_session:
        if hermes_session_id:
            record = store.find_latest_for_hermes_session(hermes_session_id, str(project_path))
        else:
            record = store.find_latest_for_project(str(project_path))
    if record is None:
        record = SessionRecord.new(
            project_path=str(project_path),
            transport=transport,
            mode=mode,
            model=model,
            permission_policy=mode,
        )
    record.project_path = str(project_path)
    record.transport = transport
    record.mode = mode
    record.permission_policy = mode
    record.model = model
    record.hermes_session_id = hermes_session_id or record.hermes_session_id
    return store.upsert(record)
