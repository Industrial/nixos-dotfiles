"""Tiny stdio MCP server exposing Hermes Cursor Harness context to Cursor."""

from __future__ import annotations

import json
import sys
from typing import Any, Callable

from .config import load_config
from .events import event
from .proposal_queue import enqueue_cursor_proposal
from .sdk_runner import sdk_node_dir, sdk_status
from .store import HarnessStore


ToolHandler = Callable[[dict[str, Any]], dict[str, Any]]


TOOLS: dict[str, dict[str, Any]] = {
    "hermes_cursor_status": {
        "description": "List Hermes Cursor Harness sessions.",
        "inputSchema": {"type": "object", "properties": {}},
        "annotations": {"readOnlyHint": True},
    },
    "hermes_cursor_events": {
        "description": "Read stored Hermes Cursor Harness events for a session.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "harness_session_id": {"type": "string"},
                "limit": {"type": "integer", "default": 50},
            },
            "required": ["harness_session_id"],
        },
        "annotations": {"readOnlyHint": True},
    },
    "hermes_cursor_project_context": {
        "description": "Return configured project aliases and latest session for a project.",
        "inputSchema": {
            "type": "object",
            "properties": {"project": {"type": "string"}},
        },
        "annotations": {"readOnlyHint": True},
    },
    "hermes_cursor_latest": {
        "description": "Return the latest harness session, optionally for a project alias/path.",
        "inputSchema": {
            "type": "object",
            "properties": {"project": {"type": "string"}},
        },
        "annotations": {"readOnlyHint": True},
    },
    "hermes_cursor_sdk_status": {
        "description": "Return local Cursor SDK bridge status for the Hermes Cursor Harness.",
        "inputSchema": {"type": "object", "properties": {}},
        "annotations": {"readOnlyHint": True},
    },
    "hermes_cursor_append_event": {
        "description": "Append a Cursor-originated progress, result, or warning event to a Hermes harness session.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "harness_session_id": {"type": "string"},
                "event_type": {"type": "string", "default": "cursor_note"},
                "text": {"type": "string"},
                "payload": {"type": "object"},
            },
            "required": ["harness_session_id", "text"],
        },
        "annotations": {"readOnlyHint": False},
    },
    "hermes_cursor_propose": {
        "description": "Create a reviewable Cursor-to-Hermes proposal without mutating Hermes memory, policy, or tools.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "kind": {
                    "type": "string",
                    "enum": ["memory_update", "task_update", "hermes_action", "tool_request", "question", "handoff", "note", "other"],
                },
                "title": {"type": "string"},
                "body": {"type": "string"},
                "priority": {"type": "string", "enum": ["low", "normal", "high", "urgent"]},
                "harness_session_id": {"type": "string"},
                "cursor_session_id": {"type": "string"},
                "project": {"type": "string"},
                "payload": {"type": "object"},
            },
            "required": ["title", "body"],
        },
        "annotations": {"readOnlyHint": False},
    },
}


def main() -> int:
    server = McpServer()
    return server.serve()


class McpServer:
    def __init__(self, *, cfg=None, store: HarnessStore | None = None) -> None:
        self.cfg = cfg or load_config()
        self.store = store or HarnessStore(self.cfg.state_dir)

    def serve(self) -> int:
        for line in sys.stdin:
            if not line.strip():
                continue
            try:
                message = json.loads(line)
                response = self.handle(message)
            except Exception as exc:
                response = _error(None, -32000, str(exc))
            if response is not None:
                _write(response)
        return 0

    def handle(self, message: dict[str, Any]) -> dict[str, Any] | None:
        method = message.get("method")
        request_id = message.get("id")
        if method == "initialize":
            return _result(
                request_id,
                {
                    "protocolVersion": "2025-06-18",
                    "capabilities": {"tools": {}},
                    "serverInfo": {"name": "hermes-cursor-harness", "version": "0.1.1"},
                },
            )
        if method == "notifications/initialized":
            return None
        if method == "tools/list":
            return _result(
                request_id,
                {
                    "tools": [
                        {
                            "name": name,
                            "description": spec["description"],
                            "inputSchema": spec["inputSchema"],
                            "annotations": spec.get("annotations", {}),
                        }
                        for name, spec in TOOLS.items()
                    ]
                },
            )
        if method == "tools/call":
            params = message.get("params") or {}
            name = params.get("name")
            arguments = params.get("arguments") or {}
            try:
                payload = self.call_tool(str(name), arguments)
                return _result(request_id, _tool_result(payload))
            except Exception as exc:
                return _result(request_id, _tool_result({"success": False, "error": str(exc)}, is_error=True))
        return _error(request_id, -32601, f"Method not found: {method}")

    def call_tool(self, name: str, args: dict[str, Any]) -> dict[str, Any]:
        if name == "hermes_cursor_status":
            return {"success": True, "sessions": self.store.list_sessions(), "state_dir": str(self.cfg.state_dir)}
        if name == "hermes_cursor_events":
            limit = int(args.get("limit", 50))
            events = self.store.read_events(str(args.get("harness_session_id") or ""), None if limit < 0 else limit)
            return {"success": True, "events": events}
        if name == "hermes_cursor_project_context":
            project = str(args.get("project") or "")
            latest = _latest_for_project(self.cfg, self.store, project) if project else None
            return {
                "success": True,
                "projects": self.cfg.projects,
                "latest_session": latest,
                "permission_context": {
                    "trusted_readonly_mcp_tools": self.cfg.trusted_readonly_mcp_tools,
                    "default_permission_policy": self.cfg.default_permission_policy,
                },
            }
        if name == "hermes_cursor_latest":
            project = str(args.get("project") or "")
            latest = _latest_for_project(self.cfg, self.store, project) if project else _latest(self.store.list_sessions())
            return {"success": True, "latest_session": latest}
        if name == "hermes_cursor_sdk_status":
            status = sdk_status(self.cfg, timeout_sec=20)
            status["sdk_node_dir"] = str(sdk_node_dir(self.cfg))
            return status
        if name == "hermes_cursor_append_event":
            return self._append_cursor_event(args)
        if name == "hermes_cursor_propose":
            return self._enqueue_cursor_proposal(args)
        raise ValueError(f"Unknown tool: {name}")

    def _append_cursor_event(self, args: dict[str, Any]) -> dict[str, Any]:
        harness_session_id = str(args.get("harness_session_id") or "").strip()
        if not harness_session_id:
            raise ValueError("harness_session_id is required")
        record = self.store.get(harness_session_id)
        if record is None:
            raise ValueError(f"unknown harness_session_id {harness_session_id}")
        text = str(args.get("text") or "").strip()
        if not text:
            raise ValueError("text is required")
        if len(text) > 12000:
            raise ValueError("text must be <= 12000 characters")
        payload = args.get("payload") if isinstance(args.get("payload"), dict) else {}
        item = self.store.append_event(
            harness_session_id,
            event(
                "cursor_companion_event",
                source="cursor_mcp",
                event_type=str(args.get("event_type") or "cursor_note").strip()[:80] or "cursor_note",
                text=text,
                payload=payload,
                cursor_session_id=record.cursor_session_id,
            ),
        )
        return {"success": True, "event": item}

    def _enqueue_cursor_proposal(self, args: dict[str, Any]) -> dict[str, Any]:
        payload = dict(args)
        payload["source"] = "cursor_mcp"
        harness_session_id = str(payload.get("harness_session_id") or "").strip()
        if harness_session_id:
            record = self.store.get(harness_session_id)
            if record is None:
                raise ValueError(f"unknown harness_session_id {harness_session_id}")
            payload.setdefault("cursor_session_id", record.cursor_session_id)
            payload.setdefault("project", record.project_path)
        item = enqueue_cursor_proposal(self.cfg, payload)
        if item.get("harness_session_id"):
            self.store.append_event(
                str(item["harness_session_id"]),
                event(
                    "cursor_companion_proposal",
                    source="cursor_mcp",
                    proposal_id=item["id"],
                    proposal_kind=item["kind"],
                    title=item["title"],
                    text=item["body"],
                    priority=item["priority"],
                    cursor_session_id=item.get("cursor_session_id"),
                ),
            )
        return {"success": True, "proposal": item}


def _latest_for_project(cfg, store: HarnessStore, project: str) -> dict[str, Any] | None:
    try:
        project_path = str(cfg.resolve_project(project))
    except Exception:
        project_path = project
    sessions = [item for item in store.list_sessions() if item.get("project_path") == project_path]
    return _latest(sessions)


def _latest(sessions: list[dict[str, Any]]) -> dict[str, Any] | None:
    if not sessions:
        return None
    return sorted(sessions, key=lambda item: int(item.get("updated_at_ms", 0)), reverse=True)[0]


def _tool_result(payload: dict[str, Any], *, is_error: bool = False) -> dict[str, Any]:
    return {
        "content": [{"type": "text", "text": json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True)}],
        "isError": is_error,
    }


def _result(request_id: Any, result: Any) -> dict[str, Any]:
    return {"jsonrpc": "2.0", "id": request_id, "result": result}


def _error(request_id: Any, code: int, message: str) -> dict[str, Any]:
    return {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}


def _write(message: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(message, ensure_ascii=False) + "\n")
    sys.stdout.flush()


if __name__ == "__main__":
    raise SystemExit(main())
