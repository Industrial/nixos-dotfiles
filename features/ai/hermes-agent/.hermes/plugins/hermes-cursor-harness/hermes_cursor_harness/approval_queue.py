"""File-backed approval queue for Hermes UI approval bridges."""

from __future__ import annotations

import json
import sys
import time
import uuid
from pathlib import Path
from typing import Any

from .config import HarnessConfig


TERMINAL_STATUSES = {"approved", "rejected", "expired", "cancelled"}


def enqueue_approval_request(cfg: HarnessConfig, payload: dict[str, Any], *, timeout_sec: float | None = None) -> dict[str, Any]:
    request_id = f"hca_{uuid.uuid4().hex[:16]}"
    created_at_ms = _now_ms()
    item = {
        "id": request_id,
        "status": "pending",
        "created_at_ms": created_at_ms,
        "updated_at_ms": created_at_ms,
        "expires_at_ms": created_at_ms + int((timeout_sec or cfg.approval_bridge_timeout_sec) * 1000),
        "policy": payload.get("policy"),
        "options": payload.get("options") or [],
        "request": payload.get("request") or {},
    }
    _write_item(cfg, item)
    return item


def wait_for_approval_decision(
    cfg: HarnessConfig,
    request_id: str,
    *,
    timeout_sec: float | None = None,
    poll_interval_sec: float = 0.1,
) -> dict[str, Any]:
    deadline = time.time() + float(timeout_sec or cfg.approval_bridge_timeout_sec)
    while time.time() < deadline:
        item = get_approval_request(cfg, request_id)
        if not item:
            raise ValueError(f"unknown approval request {request_id}")
        if item.get("status") in TERMINAL_STATUSES:
            return item
        time.sleep(poll_interval_sec)
    return decide_approval_request(cfg, request_id, outcome="expired", reason="approval bridge timed out")


def list_approval_requests(cfg: HarnessConfig, *, include_resolved: bool = False) -> list[dict[str, Any]]:
    items = []
    for path in sorted(_approval_dir(cfg).glob("*.json")):
        try:
            item = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue
        if include_resolved or item.get("status") == "pending":
            items.append(item)
    return sorted(items, key=lambda item: int(item.get("updated_at_ms", 0)), reverse=True)


def get_approval_request(cfg: HarnessConfig, request_id: str) -> dict[str, Any] | None:
    path = _approval_path(cfg, request_id)
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def decide_approval_request(
    cfg: HarnessConfig,
    request_id: str,
    *,
    option_id: str | None = None,
    outcome: str | None = None,
    reason: str | None = None,
) -> dict[str, Any]:
    item = get_approval_request(cfg, request_id)
    if not item:
        raise ValueError(f"unknown approval request {request_id}")
    if item.get("status") in TERMINAL_STATUSES:
        return item
    options = item.get("options") or []
    valid_option_ids = {str(option.get("optionId")) for option in options if option.get("optionId")}
    selected_option = str(option_id).strip() if option_id else None
    selected_outcome = str(outcome or "").strip().lower()
    if selected_option and selected_option not in valid_option_ids:
        raise ValueError(f"unknown option_id {selected_option!r} for approval request {request_id}")
    if not selected_option and selected_outcome in {"reject", "rejected", "cancel", "cancelled", "expired"}:
        selected_option = _first_option_id(options, ["reject_once", "reject_always"])
    if not selected_option and selected_outcome not in {"expired", "cancelled"}:
        raise ValueError("option_id is required unless outcome is reject, cancelled, or expired")
    status = _status_for_decision(selected_option=selected_option, outcome=selected_outcome, options=options)
    item.update(
        {
            "status": status,
            "selected_option": selected_option,
            "outcome": selected_outcome or status,
            "reason": reason or "",
            "updated_at_ms": _now_ms(),
        }
    )
    _write_item(cfg, item)
    return item


def bridge_response_from_decision(item: dict[str, Any]) -> dict[str, Any]:
    option_id = item.get("selected_option")
    if option_id:
        return {"optionId": option_id}
    outcome = str(item.get("outcome") or item.get("status") or "reject").lower()
    if outcome == "expired":
        return {"outcome": "reject", "reason": "approval request expired"}
    return {"outcome": outcome}


def approval_bridge_stdio(cfg: HarnessConfig, *, timeout_sec: float | None = None) -> dict[str, Any]:
    payload = json.load(sys.stdin)
    item = enqueue_approval_request(cfg, payload, timeout_sec=timeout_sec)
    decision = wait_for_approval_decision(cfg, item["id"], timeout_sec=timeout_sec)
    return bridge_response_from_decision(decision)


def _approval_dir(cfg: HarnessConfig) -> Path:
    path = cfg.state_dir / "approvals"
    path.mkdir(parents=True, exist_ok=True)
    return path


def _approval_path(cfg: HarnessConfig, request_id: str) -> Path:
    safe = "".join(ch for ch in str(request_id) if ch.isalnum() or ch in {"_", "-"})
    return _approval_dir(cfg) / f"{safe}.json"


def _write_item(cfg: HarnessConfig, item: dict[str, Any]) -> None:
    path = _approval_path(cfg, str(item["id"]))
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(item, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(path)


def _first_option_id(options: list[dict[str, Any]], kinds: list[str]) -> str | None:
    for kind in kinds:
        for option in options:
            if option.get("kind") == kind and option.get("optionId"):
                return str(option["optionId"])
    return None


def _status_for_decision(*, selected_option: str | None, outcome: str, options: list[dict[str, Any]]) -> str:
    if outcome in {"expired", "cancelled"}:
        return outcome
    option = next((item for item in options if str(item.get("optionId")) == selected_option), None)
    kind = str((option or {}).get("kind") or "").lower()
    if kind.startswith("allow"):
        return "approved"
    return "rejected"


def _now_ms() -> int:
    return int(time.time() * 1000)
