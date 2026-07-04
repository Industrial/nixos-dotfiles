"""File-backed proposal queue for Cursor-to-Hermes handoffs.

Cursor may use this queue to ask Hermes for memory/task/tool/action changes.
The queue is intentionally review-gated: proposals are stored for Hermes to
accept, reject, mark done, or archive, but they do not mutate Hermes authority
state by themselves.
"""

from __future__ import annotations

import json
import time
import uuid
from pathlib import Path
from typing import Any

from .config import HarnessConfig
from .events import event
from .store import HarnessStore


PROPOSAL_KINDS = {
    "memory_update",
    "task_update",
    "hermes_action",
    "tool_request",
    "question",
    "handoff",
    "note",
    "other",
}
TERMINAL_STATUSES = {"accepted", "rejected", "done", "archived", "cancelled"}
PRIORITY_ORDER = {"urgent": 0, "high": 1, "normal": 2, "low": 3}


def enqueue_cursor_proposal(cfg: HarnessConfig, payload: dict[str, Any]) -> dict[str, Any]:
    created_at_ms = _now_ms()
    proposal_id = f"hcp_{uuid.uuid4().hex[:16]}"
    kind = _clean_kind(payload.get("kind"))
    item = {
        "id": proposal_id,
        "status": "pending",
        "kind": kind,
        "title": _require_text(payload.get("title"), "title", max_length=240),
        "body": _require_text(payload.get("body") or payload.get("text"), "body", max_length=12000),
        "priority": _clean_priority(payload.get("priority")),
        "source": _clean_optional_text(payload.get("source"), max_length=80) or "cursor_mcp",
        "harness_session_id": _clean_optional_text(payload.get("harness_session_id"), max_length=160),
        "cursor_session_id": _clean_optional_text(payload.get("cursor_session_id"), max_length=240),
        "project": _clean_optional_text(payload.get("project"), max_length=4096),
        "payload": payload.get("payload") if isinstance(payload.get("payload"), dict) else {},
        "created_at_ms": created_at_ms,
        "updated_at_ms": created_at_ms,
        "resolution": {},
    }
    _write_item(cfg, item)
    return item


def list_cursor_proposals(cfg: HarnessConfig, *, include_resolved: bool = False) -> list[dict[str, Any]]:
    items = []
    for path in sorted(_proposal_dir(cfg).glob("*.json")):
        try:
            item = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue
        if include_resolved or item.get("status") == "pending":
            items.append(item)
    return sorted(items, key=lambda item: int(item.get("updated_at_ms", 0)), reverse=True)


def proposal_inbox(
    cfg: HarnessConfig,
    *,
    store: HarnessStore | None = None,
    include_resolved: bool = False,
    limit: int = 50,
) -> dict[str, Any]:
    """Return a Hermes UI-friendly proposal inbox with linked session context."""

    store = store or HarnessStore(cfg.state_dir)
    proposals = list_cursor_proposals(cfg, include_resolved=include_resolved)
    counts: dict[str, int] = {"pending": 0, "resolved": 0}
    by_kind: dict[str, int] = {}
    by_priority: dict[str, int] = {}
    items: list[dict[str, Any]] = []
    for proposal in proposals:
        status = str(proposal.get("status") or "pending")
        counts["pending" if status == "pending" else "resolved"] += 1
        kind = str(proposal.get("kind") or "other")
        priority = str(proposal.get("priority") or "normal")
        by_kind[kind] = by_kind.get(kind, 0) + 1
        by_priority[priority] = by_priority.get(priority, 0) + 1
        session = None
        events: list[dict[str, Any]] = []
        harness_session_id = proposal.get("harness_session_id")
        if harness_session_id:
            record = store.get(str(harness_session_id))
            session = record.__dict__ if record else None
            events = [
                event
                for event in store.read_events(str(harness_session_id), limit=-1)
                if event.get("proposal_id") == proposal.get("id")
            ][-5:]
        items.append(
            {
                "proposal": proposal,
                "session": session,
                "linked_events": events,
                "actions": _proposal_actions(proposal),
            }
        )
    items = sorted(items, key=_inbox_sort_key)
    if limit >= 0:
        items = items[:limit]
    return {
        "success": True,
        "summary": {
            "total": len(proposals),
            "pending": counts["pending"],
            "resolved": counts["resolved"],
            "by_kind": by_kind,
            "by_priority": by_priority,
        },
        "items": items,
        "next_actions": [
            "Review pending proposals with action=get or the proposal inbox.",
            "Resolve each pending proposal with accept, reject, done, archive, or cancel.",
        ],
    }


def proposal_inbox_text(inbox: dict[str, Any]) -> str:
    """Render a compact terminal inbox for humans reviewing Cursor proposals."""

    summary = inbox.get("summary") if isinstance(inbox.get("summary"), dict) else {}
    lines = [
        "Cursor Proposal Inbox",
        (
            f"pending={int(summary.get('pending') or 0)} "
            f"resolved={int(summary.get('resolved') or 0)} "
            f"total={int(summary.get('total') or 0)}"
        ),
    ]
    items = inbox.get("items") if isinstance(inbox.get("items"), list) else []
    if not items:
        lines.append("")
        lines.append("No proposals to review.")
        return "\n".join(lines)

    for item in items:
        proposal = item.get("proposal") if isinstance(item, dict) else {}
        if not isinstance(proposal, dict):
            continue
        proposal_id = str(proposal.get("id") or "(unknown)")
        status = str(proposal.get("status") or "pending")
        priority = str(proposal.get("priority") or "normal")
        kind = str(proposal.get("kind") or "other")
        title = _single_line(proposal.get("title") or "(untitled)", max_length=88)
        updated_at = _format_ms(proposal.get("updated_at_ms") or proposal.get("created_at_ms"))
        actions = ", ".join(str(action) for action in (item.get("actions") or []))
        linked_events = item.get("linked_events") if isinstance(item.get("linked_events"), list) else []
        session = item.get("session") if isinstance(item.get("session"), dict) else None

        lines.append("")
        lines.append(f"[{priority}] {proposal_id}  {status}  {kind}")
        lines.append(f"  {title}")
        if proposal.get("harness_session_id"):
            session_name = _single_line((session or {}).get("name") or "", max_length=48)
            suffix = f" ({session_name})" if session_name else ""
            lines.append(f"  Session: {proposal.get('harness_session_id')}{suffix}")
        if proposal.get("project"):
            lines.append(f"  Project: {_single_line(proposal.get('project'), max_length=96)}")
        lines.append(f"  Updated: {updated_at}")
        if actions:
            lines.append(f"  Actions: {actions}")
        if linked_events:
            lines.append(f"  Linked events: {len(linked_events)}")
    return "\n".join(lines)


def get_cursor_proposal(cfg: HarnessConfig, proposal_id: str) -> dict[str, Any] | None:
    path = _proposal_path(cfg, proposal_id)
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def resolve_cursor_proposal(
    cfg: HarnessConfig,
    proposal_id: str,
    *,
    status: str,
    reason: str | None = None,
    resolution: dict[str, Any] | None = None,
) -> dict[str, Any]:
    item = get_cursor_proposal(cfg, proposal_id)
    if not item:
        raise ValueError(f"unknown proposal_id {proposal_id}")
    current_status = str(item.get("status") or "pending").strip().lower()
    if current_status != "pending":
        raise ValueError(f"proposal_id {proposal_id} is already resolved as {current_status}")
    clean_status = str(status or "").strip().lower()
    if clean_status not in TERMINAL_STATUSES:
        raise ValueError(f"status must be one of {sorted(TERMINAL_STATUSES)}")
    merged_resolution = dict(item.get("resolution") or {})
    if resolution:
        merged_resolution.update(resolution)
    if reason:
        merged_resolution["reason"] = str(reason)
    item.update(
        {
            "status": clean_status,
            "resolution": merged_resolution,
            "updated_at_ms": _now_ms(),
        }
    )
    _write_item(cfg, item)
    return item


def append_proposal_resolution_event(
    cfg: HarnessConfig,
    proposal: dict[str, Any],
    *,
    source: str = "hermes",
) -> dict[str, Any] | None:
    """Mirror Hermes' proposal decision into the related harness session."""

    harness_session_id = _clean_optional_text(proposal.get("harness_session_id"), max_length=160)
    if not harness_session_id:
        return None
    store = HarnessStore(cfg.state_dir)
    if store.get(harness_session_id) is None:
        return None
    resolution = proposal.get("resolution") if isinstance(proposal.get("resolution"), dict) else {}
    reason = str(resolution.get("reason") or "").strip()
    text = reason or f"Proposal {proposal.get('id')} resolved as {proposal.get('status')}."
    return store.append_event(
        harness_session_id,
        event(
            "cursor_companion_proposal_resolution",
            source=source,
            proposal_id=proposal.get("id"),
            proposal_kind=proposal.get("kind"),
            title=proposal.get("title"),
            status=proposal.get("status"),
            text=text,
            resolution=resolution,
            cursor_session_id=proposal.get("cursor_session_id"),
        ),
    )


def _proposal_actions(proposal: dict[str, Any]) -> list[str]:
    if str(proposal.get("status") or "pending") != "pending":
        return ["get"]
    return ["get", "accept", "reject", "done", "archive", "cancel"]


def _inbox_sort_key(item: dict[str, Any]) -> tuple[int, int, int]:
    proposal = item.get("proposal") or {}
    status_rank = 0 if proposal.get("status") == "pending" else 1
    priority_rank = PRIORITY_ORDER.get(str(proposal.get("priority") or "normal"), 2)
    updated_desc = -int(proposal.get("updated_at_ms") or 0)
    return (status_rank, priority_rank, updated_desc)


def _proposal_dir(cfg: HarnessConfig) -> Path:
    path = cfg.state_dir / "cursor_proposals"
    path.mkdir(parents=True, exist_ok=True)
    return path


def _proposal_path(cfg: HarnessConfig, proposal_id: str) -> Path:
    return _proposal_dir(cfg) / f"{_clean_proposal_id(proposal_id)}.json"


def _write_item(cfg: HarnessConfig, item: dict[str, Any]) -> None:
    path = _proposal_path(cfg, str(item["id"]))
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(item, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(path)


def _clean_kind(raw: Any) -> str:
    kind = str(raw or "other").strip().lower()
    return kind if kind in PROPOSAL_KINDS else "other"


def _clean_priority(raw: Any) -> str:
    priority = str(raw or "normal").strip().lower()
    return priority if priority in {"low", "normal", "high", "urgent"} else "normal"


def _clean_proposal_id(raw: Any) -> str:
    proposal_id = str(raw or "").strip()
    if not proposal_id:
        raise ValueError("proposal_id is required")
    if len(proposal_id) > 200:
        raise ValueError("proposal_id must be <= 200 characters")
    if any(ch not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" for ch in proposal_id):
        raise ValueError("proposal_id may only contain letters, numbers, underscores, and hyphens")
    return proposal_id


def _require_text(raw: Any, name: str, *, max_length: int) -> str:
    text = str(raw or "").strip()
    if not text:
        raise ValueError(f"{name} is required")
    if len(text) > max_length:
        raise ValueError(f"{name} must be <= {max_length} characters")
    return text


def _clean_optional_text(raw: Any, *, max_length: int) -> str | None:
    if raw is None:
        return None
    text = str(raw).strip()
    if not text:
        return None
    return text[:max_length]


def _single_line(raw: Any, *, max_length: int) -> str:
    text = " ".join(str(raw or "").split())
    if len(text) <= max_length:
        return text
    return text[: max(0, max_length - 1)].rstrip() + "..."


def _format_ms(raw: Any) -> str:
    try:
        value = int(raw)
    except (TypeError, ValueError):
        return "(unknown)"
    if value <= 0:
        return "(unknown)"
    return time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime(value / 1000))


def _now_ms() -> int:
    return int(time.time() * 1000)
