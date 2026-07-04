"""Persistent session and event storage for the Cursor harness."""

from __future__ import annotations

import json
import shutil
import threading
import uuid
from dataclasses import asdict, dataclass, fields
from pathlib import Path
from typing import Any

from .events import now_ms


@dataclass
class SessionRecord:
    harness_session_id: str
    project_path: str
    transport: str
    hermes_session_id: str | None = None
    status: str = "idle"
    cursor_session_id: str | None = None
    last_sdk_run_id: str | None = None
    mode: str = "plan"
    model: str | None = None
    permission_policy: str = "plan"
    created_at_ms: int = 0
    updated_at_ms: int = 0
    event_count: int = 0
    last_error: str | None = None
    last_result: str | None = None
    last_stop_reason: str | None = None
    name: str | None = None
    tags: list[str] | None = None
    archived: bool = False

    @classmethod
    def new(cls, *, project_path: str, transport: str, mode: str, model: str | None, permission_policy: str) -> "SessionRecord":
        ts = now_ms()
        return cls(
            harness_session_id=f"hch_{uuid.uuid4().hex[:16]}",
            project_path=project_path,
            transport=transport,
            mode=mode,
            model=model,
            permission_policy=permission_policy,
            created_at_ms=ts,
            updated_at_ms=ts,
        )


class HarnessStore:
    """Small JSON/JSONL store under ~/.hermes/cursor_harness by default."""

    def __init__(self, state_dir: str | Path):
        self.state_dir = Path(state_dir)
        self.state_dir.mkdir(parents=True, exist_ok=True)
        self.events_dir = self.state_dir / "events"
        self.events_dir.mkdir(parents=True, exist_ok=True)
        self.state_path = self.state_dir / "state.json"
        self._lock = threading.RLock()

    def list_sessions(self) -> list[dict[str, Any]]:
        with self._lock:
            return list(self._read_state().get("sessions", {}).values())

    def get(self, harness_session_id: str) -> SessionRecord | None:
        with self._lock:
            raw = self._read_state().get("sessions", {}).get(harness_session_id)
            return _session_record_from_raw(raw) if raw else None

    def find_latest_for_project(self, project_path: str) -> SessionRecord | None:
        with self._lock:
            sessions = [
                _session_record_from_raw(raw)
                for raw in self._read_state().get("sessions", {}).values()
                if raw.get("project_path") == project_path
            ]
        if not sessions:
            return None
        return sorted(sessions, key=lambda item: item.updated_at_ms, reverse=True)[0]

    def find_latest_for_hermes_session(
        self,
        hermes_session_id: str,
        project_path: str | None = None,
    ) -> SessionRecord | None:
        with self._lock:
            sessions = []
            for raw in self._read_state().get("sessions", {}).values():
                if raw.get("hermes_session_id") != hermes_session_id:
                    continue
                if project_path is not None and raw.get("project_path") != project_path:
                    continue
                sessions.append(_session_record_from_raw(raw))
        if not sessions:
            return None
        return sorted(sessions, key=lambda item: item.updated_at_ms, reverse=True)[0]

    def upsert(self, record: SessionRecord) -> SessionRecord:
        with self._lock:
            state = self._read_state()
            existing = state.setdefault("sessions", {}).get(record.harness_session_id)
            if isinstance(existing, dict):
                record.event_count = max(int(existing.get("event_count", 0)), int(record.event_count or 0))
            record.updated_at_ms = now_ms()
            state["sessions"][record.harness_session_id] = asdict(record)
            self._write_state(state)
            return record

    def append_event(self, harness_session_id: str, item: dict[str, Any]) -> dict[str, Any]:
        with self._lock:
            record = self.get(harness_session_id)
            sequence = (record.event_count if record else 0) + 1
            item = dict(item)
            item["sequence"] = sequence
            with self._event_path(harness_session_id).open("a", encoding="utf-8") as handle:
                handle.write(json.dumps(item, ensure_ascii=False, sort_keys=True) + "\n")
            if record:
                record.event_count = sequence
                self.upsert(record)
            return item

    def read_events(self, harness_session_id: str, limit: int | None = None) -> list[dict[str, Any]]:
        path = self._event_path(harness_session_id)
        if not path.exists():
            return []
        with path.open("r", encoding="utf-8") as handle:
            rows = [json.loads(line) for line in handle if line.strip()]
        if limit is not None and limit >= 0:
            return rows[-limit:]
        return rows

    def update_session(
        self,
        harness_session_id: str,
        *,
        name: str | None = None,
        tags: list[str] | None = None,
        archived: bool | None = None,
    ) -> SessionRecord:
        record = self.get(harness_session_id)
        if record is None:
            raise ValueError(f"unknown harness_session_id {harness_session_id}")
        if name is not None:
            record.name = name or None
        if tags is not None:
            record.tags = [clean for tag in tags if (clean := str(tag).strip())]
        if archived is not None:
            record.archived = bool(archived)
        return self.upsert(record)

    def export_session(self, harness_session_id: str, output_dir: str | Path | None = None) -> dict[str, Any]:
        record = self.get(harness_session_id)
        if record is None:
            raise ValueError(f"unknown harness_session_id {harness_session_id}")
        target_dir = Path(output_dir) if output_dir else self.state_dir / "exports"
        target_dir.mkdir(parents=True, exist_ok=True)
        export_path = target_dir / f"{harness_session_id}.json"
        payload = {"session": record.__dict__, "events": self.read_events(harness_session_id, limit=-1)}
        export_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return {"success": True, "path": str(export_path), "event_count": len(payload["events"])}

    def prune_sessions(self, *, keep_last: int = 50, include_archived: bool = True, dry_run: bool = False) -> dict[str, Any]:
        sessions = sorted(self.list_sessions(), key=lambda item: int(item.get("updated_at_ms", 0)), reverse=True)
        keep_ids = {item.get("harness_session_id") for item in sessions[: max(0, int(keep_last))]}
        candidates = [
            item
            for item in sessions
            if item.get("harness_session_id") not in keep_ids and (include_archived or not item.get("archived"))
        ]
        removed: list[str] = []
        if not dry_run:
            with self._lock:
                state = self._read_state()
                session_map = state.setdefault("sessions", {})
                for item in candidates:
                    sid = str(item.get("harness_session_id") or "")
                    if not sid:
                        continue
                    session_map.pop(sid, None)
                    event_path = self._event_path(sid)
                    if event_path.exists():
                        event_path.unlink()
                    removed.append(sid)
                self._write_state(state)
        else:
            removed = [str(item.get("harness_session_id")) for item in candidates if item.get("harness_session_id")]
        return {"success": True, "dry_run": dry_run, "removed": removed, "kept": len(keep_ids)}

    def record_background_agent(self, agent: dict[str, Any]) -> None:
        agent_id = str(agent.get("id") or agent.get("agent_id") or agent.get("agentId") or "")
        if not agent_id:
            return
        with self._lock:
            state = self._read_state()
            state.setdefault("background_agents", {})[agent_id] = dict(agent)
            self._write_state(state)

    def list_background_agents(self) -> list[dict[str, Any]]:
        with self._lock:
            agents = self._read_state().get("background_agents", {})
            return list(agents.values()) if isinstance(agents, dict) else []

    def clear_exports(self) -> None:
        exports = self.state_dir / "exports"
        if exports.exists():
            shutil.rmtree(exports)

    def _event_path(self, harness_session_id: str) -> Path:
        safe = "".join(ch for ch in harness_session_id if ch.isalnum() or ch in {"_", "-"})
        return self.events_dir / f"{safe}.jsonl"

    def _read_state(self) -> dict[str, Any]:
        if not self.state_path.exists():
            return {"sessions": {}}
        with self.state_path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        if not isinstance(data, dict):
            return {"sessions": {}}
        data.setdefault("sessions", {})
        data.setdefault("background_agents", {})
        return data

    def _write_state(self, state: dict[str, Any]) -> None:
        tmp = self.state_path.with_suffix(".json.tmp")
        with tmp.open("w", encoding="utf-8") as handle:
            json.dump(state, handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.write("\n")
        tmp.replace(self.state_path)


def _session_record_from_raw(raw: dict[str, Any]) -> SessionRecord:
    allowed = {field.name for field in fields(SessionRecord)}
    return SessionRecord(**{key: value for key, value in raw.items() if key in allowed})
