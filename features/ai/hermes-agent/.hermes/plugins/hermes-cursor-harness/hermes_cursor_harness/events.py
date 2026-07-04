"""Event normalization for Cursor ACP and stream-json outputs."""

from __future__ import annotations

import time
from typing import Any


def now_ms() -> int:
    return int(time.time() * 1000)


def event(kind: str, **kwargs: Any) -> dict[str, Any]:
    data = {"type": kind, "timestamp_ms": now_ms()}
    data.update({key: value for key, value in kwargs.items() if value is not None})
    return data


def extract_text_content(content: Any) -> str:
    """Extract text from ACP/Cursor content blocks."""

    if isinstance(content, str):
        return content
    if isinstance(content, dict):
        if content.get("type") == "text":
            return str(content.get("text") or "")
        if "content" in content:
            return extract_text_content(content.get("content"))
    if isinstance(content, list):
        return "".join(extract_text_content(item) for item in content)
    return ""


def normalize_stream_json(raw: dict[str, Any]) -> list[dict[str, Any]]:
    """Normalize Cursor Agent stream-json lines into harness events."""

    etype = raw.get("type")
    subtype = raw.get("subtype")
    session_id = raw.get("session_id")
    if etype == "system" and subtype == "init":
        return [
            event(
                "session_started",
                source="cursor_stream",
                cursor_session_id=session_id,
                model=raw.get("model"),
                cwd=raw.get("cwd"),
                raw=raw,
            )
        ]
    if etype in {"assistant", "user"}:
        text = extract_text_content((raw.get("message") or {}).get("content"))
        if not text:
            return []
        return [
            event(
                "message_delta",
                source="cursor_stream",
                role=etype,
                text=text,
                cursor_session_id=session_id,
                raw=raw,
            )
        ]
    if etype == "tool_call":
        tool_name, payload = extract_cursor_tool(raw.get("tool_call"))
        return [
            event(
                "tool_call",
                source="cursor_stream",
                subtype=subtype,
                call_id=raw.get("call_id") or raw.get("tool_call_id"),
                tool_name=tool_name,
                payload=payload,
                cursor_session_id=session_id,
                raw=raw,
            )
        ]
    if etype == "result":
        return [
            event(
                "turn_result",
                source="cursor_stream",
                success=(subtype in {None, "success"}) and not raw.get("is_error", False),
                text=raw.get("result") or raw.get("message") or "",
                cursor_session_id=session_id,
                duration_ms=raw.get("duration_ms"),
                raw=raw,
            )
        ]
    return [event("raw", source="cursor_stream", raw=raw)]


def normalize_sdk_json(raw: dict[str, Any]) -> list[dict[str, Any]]:
    """Normalize Cursor SDK bridge JSONL records into harness events."""

    bridge_type = raw.get("type")
    agent_id = raw.get("agent_id") or raw.get("agentId")
    run_id = raw.get("run_id") or raw.get("runId")
    if bridge_type == "agent":
        return [
            event(
                "session_started",
                source="cursor_sdk",
                cursor_session_id=agent_id,
                sdk_runtime=raw.get("runtime"),
                model=raw.get("model"),
                resumed=raw.get("resumed"),
                raw=raw,
            )
        ]
    if bridge_type == "run":
        return [
            event(
                "status",
                source="cursor_sdk",
                cursor_session_id=agent_id,
                sdk_run_id=run_id,
                status="RUNNING",
                raw=raw,
            )
        ]
    if bridge_type == "sdk_event":
        return normalize_sdk_message(raw.get("message") or {})
    if bridge_type == "result":
        return [
            event(
                "turn_result",
                source="cursor_sdk",
                success=raw.get("status") == "finished" and not raw.get("error"),
                text=raw.get("result") or raw.get("text") or "",
                cursor_session_id=agent_id,
                sdk_run_id=run_id,
                status=raw.get("status"),
                model=raw.get("model"),
                duration_ms=raw.get("duration_ms") or raw.get("durationMs"),
                git=raw.get("git"),
                raw=raw,
            )
        ]
    if bridge_type == "error":
        return [
            event(
                "turn_result",
                source="cursor_sdk",
                success=False,
                text="",
                cursor_session_id=agent_id,
                sdk_run_id=run_id,
                error=raw.get("error"),
                raw=raw,
            )
        ]
    return [event("raw", source="cursor_sdk", cursor_session_id=agent_id, sdk_run_id=run_id, raw=raw)]


def normalize_sdk_message(message: dict[str, Any]) -> list[dict[str, Any]]:
    """Normalize one @cursor/sdk SDKMessage into harness events."""

    if not isinstance(message, dict):
        return [event("raw", source="cursor_sdk", raw=message)]
    etype = message.get("type")
    agent_id = message.get("agent_id") or message.get("agentId")
    run_id = message.get("run_id") or message.get("runId")
    if etype == "system":
        return [
            event(
                "session_started",
                source="cursor_sdk",
                cursor_session_id=agent_id,
                sdk_run_id=run_id,
                model=message.get("model"),
                tools=message.get("tools"),
                raw=message,
            )
        ]
    if etype in {"assistant", "user"}:
        role = etype
        events: list[dict[str, Any]] = []
        content = ((message.get("message") or {}).get("content") or [])
        if not isinstance(content, list):
            content = [content]
        for block in content:
            if isinstance(block, dict) and block.get("type") == "tool_use":
                events.append(
                    event(
                        "tool_call",
                        source="cursor_sdk",
                        call_id=block.get("id"),
                        tool_name=block.get("name"),
                        payload=block.get("input"),
                        cursor_session_id=agent_id,
                        sdk_run_id=run_id,
                        raw=message,
                    )
                )
                continue
            text = extract_text_content(block)
            if text:
                events.append(
                    event(
                        "message_delta",
                        source="cursor_sdk",
                        role=role,
                        text=text,
                        cursor_session_id=agent_id,
                        sdk_run_id=run_id,
                        raw=message,
                    )
                )
        return events
    if etype == "tool_call":
        return [
            event(
                "tool_call",
                source="cursor_sdk",
                subtype=message.get("status"),
                call_id=message.get("call_id"),
                tool_name=message.get("name"),
                payload={
                    "args": message.get("args"),
                    "result": message.get("result"),
                    "truncated": message.get("truncated"),
                },
                cursor_session_id=agent_id,
                sdk_run_id=run_id,
                raw=message,
            )
        ]
    if etype == "thinking":
        text = str(message.get("text") or "")
        if not text:
            return []
        return [
            event(
                "message_delta",
                source="cursor_sdk",
                role="thought",
                text=text,
                cursor_session_id=agent_id,
                sdk_run_id=run_id,
                raw=message,
            )
        ]
    if etype == "status":
        return [
            event(
                "status",
                source="cursor_sdk",
                status=message.get("status"),
                text=message.get("message"),
                cursor_session_id=agent_id,
                sdk_run_id=run_id,
                raw=message,
            )
        ]
    if etype == "task":
        return [
            event(
                "task",
                source="cursor_sdk",
                status=message.get("status"),
                text=message.get("text"),
                cursor_session_id=agent_id,
                sdk_run_id=run_id,
                raw=message,
            )
        ]
    if etype == "request":
        return [
            event(
                "permission_request",
                source="cursor_sdk",
                cursor_session_id=agent_id,
                sdk_run_id=run_id,
                request_id=message.get("request_id"),
                raw=message,
            )
        ]
    return [event("raw", source="cursor_sdk", cursor_session_id=agent_id, sdk_run_id=run_id, raw=message)]


def normalize_acp_update(params: dict[str, Any]) -> list[dict[str, Any]]:
    """Normalize ACP session/update params into harness events."""

    update = params.get("update") or {}
    kind = update.get("sessionUpdate")
    session_id = params.get("sessionId")
    if kind in {"agent_message_chunk", "user_message_chunk", "agent_thought_chunk"}:
        text = extract_text_content(update.get("content"))
        if not text:
            return []
        role = "assistant" if kind == "agent_message_chunk" else "user"
        if kind == "agent_thought_chunk":
            role = "thought"
        return [
            event(
                "message_delta",
                source="cursor_acp",
                role=role,
                text=text,
                cursor_session_id=session_id,
                raw=params,
            )
        ]
    if kind in {"tool_call", "tool_call_update"}:
        call = update.get("toolCall") or update
        return [
            event(
                "tool_call",
                source="cursor_acp",
                subtype=kind,
                call_id=call.get("toolCallId") or update.get("toolCallId"),
                tool_name=call.get("title") or call.get("kind") or call.get("name"),
                payload=call,
                cursor_session_id=session_id,
                raw=params,
            )
        ]
    if kind == "current_mode_update":
        return [
            event(
                "mode_changed",
                source="cursor_acp",
                cursor_session_id=session_id,
                mode=update.get("currentModeId") or update.get("modeId"),
                raw=params,
            )
        ]
    if kind in {"plan", "agent_plan"}:
        entries = update.get("entries")
        text = ""
        if isinstance(entries, list):
            text = "\n".join(
                str(entry.get("content") or entry.get("text") or "")
                for entry in entries
                if isinstance(entry, dict) and (entry.get("content") or entry.get("text"))
            )
        return [event("plan", source="cursor_acp", cursor_session_id=session_id, text=text, entries=entries, raw=params)]
    return [event("raw", source="cursor_acp", cursor_session_id=session_id, raw=params)]


def extract_cursor_tool(tool_call: Any) -> tuple[str | None, Any]:
    if not isinstance(tool_call, dict) or not tool_call:
        return None, tool_call
    key = next(iter(tool_call))
    value = tool_call.get(key)
    if key.endswith("ToolCall"):
        return key[: -len("ToolCall")], value
    if key.endswith("_tool_call"):
        return key[: -len("_tool_call")], value
    return key, value


def modified_files_from_events(events: list[dict[str, Any]]) -> list[str]:
    seen: set[str] = set()
    for item in events:
        if item.get("type") != "tool_call":
            continue
        if not _is_mutating_tool_call(item):
            continue
        payload = item.get("payload")
        candidates: list[Any] = []
        if isinstance(payload, dict):
            candidates.extend(
                [
                    payload.get("path"),
                    payload.get("file"),
                    payload.get("filePath"),
                    payload.get("target_file"),
                ]
            )
            args = payload.get("args")
            if isinstance(args, dict):
                candidates.extend([args.get("path"), args.get("file"), args.get("filePath")])
        for candidate in candidates:
            if isinstance(candidate, str) and candidate:
                seen.add(candidate)
    return sorted(seen)


def _is_mutating_tool_call(item: dict[str, Any]) -> bool:
    payload = item.get("payload")
    labels = [str(item.get("tool_name") or ""), str(item.get("subtype") or "")]
    if isinstance(payload, dict):
        labels.extend(
            str(payload.get(key) or "")
            for key in ("kind", "name", "title", "toolName")
        )
        args = payload.get("args")
        if isinstance(args, dict):
            labels.extend(str(args.get(key) or "") for key in ("kind", "name", "toolName"))
    normalized = " ".join(label.lower().replace("-", "_") for label in labels if label)
    readonly_terms = ("read", "search", "grep", "glob", "list", "mcp", "status", "latest", "context")
    mutating_terms = (
        "write",
        "edit",
        "create",
        "delete",
        "remove",
        "rename",
        "move",
        "patch",
        "apply",
        "replace",
        "insert",
        "append",
        "mkdir",
    )
    if any(term in normalized for term in mutating_terms):
        return True
    if any(term in normalized for term in readonly_terms):
        return False
    return False
