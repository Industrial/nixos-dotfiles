"""Minimal ACP client for Cursor Agent server mode."""

from __future__ import annotations

import json
import os
import queue
import signal
import subprocess
import sys
import threading
import time
from typing import Any, Callable

from .approval import select_permission_option
from .child_env import cursor_child_env
from .config import HarnessConfig, resolve_acp_command
from .events import event, modified_files_from_events, normalize_acp_update
from .store import HarnessStore, SessionRecord

OnEvent = Callable[[dict[str, Any]], None]
SUCCESS_STOP_REASONS = {"end_turn", "max_tokens", "max_turn_requests"}


class AcpError(RuntimeError):
    pass


class AcpClient:
    """Synchronous JSON-RPC client over ACP's stdio transport."""

    def __init__(
        self,
        command: list[str],
        cwd: str,
        permission_policy: str,
        on_event: OnEvent,
        trusted_readonly_mcp_tools: list[str] | None = None,
        approval_bridge_command: list[str] | None = None,
        approval_bridge_timeout_sec: float = 120.0,
    ):
        self.command = command
        self.cwd = cwd
        self.permission_policy = permission_policy
        self.on_event = on_event
        self.trusted_readonly_mcp_tools = set(trusted_readonly_mcp_tools or [])
        self.approval_bridge_command = approval_bridge_command or []
        self.approval_bridge_timeout_sec = approval_bridge_timeout_sec
        self.env = cursor_child_env(include_test_controls=True)
        self.proc: subprocess.Popen[str] | None = None
        self._ids = 0
        self._stdout_q: queue.Queue[str | None] = queue.Queue()
        self._stderr_q: queue.Queue[str | None] = queue.Queue()
        self.capabilities: dict[str, Any] = {}

    def start(self) -> None:
        popen_kwargs: dict[str, Any] = {
            "stdin": subprocess.PIPE,
            "stdout": subprocess.PIPE,
            "stderr": subprocess.PIPE,
            "cwd": self.cwd,
            "text": True,
            "encoding": "utf-8",
            "errors": "replace",
            "bufsize": 1,
            "env": self.env,
        }
        if sys.platform == "win32":
            popen_kwargs["creationflags"] = getattr(subprocess, "CREATE_NO_WINDOW", 0)
        else:
            popen_kwargs["preexec_fn"] = os.setsid  # type: ignore[assignment]
        self.proc = subprocess.Popen(self.command, **popen_kwargs)
        self._start_stdout_reader()
        self._start_stderr_reader()

    def close(self) -> None:
        if self.proc is None:
            return
        if self.proc.poll() is None:
            try:
                if sys.platform == "win32":
                    self.proc.terminate()
                else:
                    os.killpg(os.getpgid(self.proc.pid), 15)
            except Exception:
                self.proc.terminate()
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                if sys.platform == "win32":
                    self.proc.kill()
                else:
                    os.killpg(os.getpgid(self.proc.pid), signal.SIGKILL)
            except Exception:
                self.proc.kill()
            self.proc.wait(timeout=5)

    def initialize(self, timeout_sec: float) -> dict[str, Any]:
        result = self.request(
            "initialize",
            {
                "protocolVersion": 1,
                "clientCapabilities": {"fs": {"readTextFile": False, "writeTextFile": False}, "terminal": False},
                "clientInfo": {"name": "hermes-cursor-harness", "title": "Hermes Cursor Harness", "version": "0.1.1"},
            },
            timeout_sec=timeout_sec,
        )
        self.capabilities = dict((result or {}).get("agentCapabilities") or {})
        return result

    def request(self, method: str, params: dict[str, Any] | None = None, timeout_sec: float = 30.0) -> Any:
        if self.proc is None or self.proc.stdin is None or self.proc.stdout is None:
            raise AcpError("ACP process is not running")
        request_id = self._next_id()
        payload = {"jsonrpc": "2.0", "id": request_id, "method": method, "params": params or {}}
        self.proc.stdin.write(json.dumps(payload, ensure_ascii=False) + "\n")
        self.proc.stdin.flush()
        deadline = time.time() + timeout_sec
        while True:
            self._drain_stderr()
            if time.time() > deadline:
                raise TimeoutError(f"ACP request {method} timed out after {timeout_sec}s")
            try:
                line = self._stdout_q.get(timeout=0.25)
            except queue.Empty:
                if self.proc.poll() is not None:
                    raise AcpError(f"ACP process exited with {self.proc.returncode}")
                continue
            if line is None:
                raise AcpError(f"ACP process exited with {self.proc.poll()}")
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                self.on_event(event("diagnostic", source="acp_stdout", text=line.rstrip()))
                continue
            message_method = message.get("method")
            if message_method == "session/update":
                for item in normalize_acp_update(message.get("params") or {}):
                    self.on_event(item)
                continue
            if message_method == "session/request_permission":
                self._handle_permission_request(message)
                continue
            if message_method and "id" in message:
                self._handle_client_request(message)
                continue
            if message.get("id") == request_id:
                if "error" in message:
                    raise AcpError(json.dumps(message["error"], ensure_ascii=False))
                return message.get("result")
            self.on_event(event("raw", source="cursor_acp", raw=message))

    def _handle_permission_request(self, message: dict[str, Any]) -> None:
        if self.proc is None or self.proc.stdin is None:
            return
        params = message.get("params") or {}
        options = params.get("options") or []
        selected, source, reason = select_permission_option(
            options=options,
            policy=self.permission_policy,
            params=params,
            trusted_readonly_mcp_tools=self.trusted_readonly_mcp_tools,
            bridge_command=self.approval_bridge_command,
            bridge_timeout_sec=self.approval_bridge_timeout_sec,
        )
        self.on_event(
            event(
                "permission_request",
                source="cursor_acp",
                cursor_session_id=params.get("sessionId"),
                selected_option=selected,
                decision_source=source,
                decision_reason=reason,
                raw=params,
            )
        )
        if "id" not in message:
            return
        outcome = {"outcome": "selected", "optionId": selected} if selected else {"outcome": "cancelled"}
        self._send_response(message.get("id"), {"outcome": outcome})

    def _handle_client_request(self, message: dict[str, Any]) -> None:
        method = str(message.get("method") or "")
        if method == "cursor/create_plan":
            self._handle_create_plan_request(message)
            return
        self._handle_unsupported_request(message)

    def _handle_create_plan_request(self, message: dict[str, Any]) -> None:
        params = message.get("params") or {}
        if not isinstance(params, dict):
            params = {}
        self.on_event(
            event(
                "plan",
                source="cursor_acp",
                method="cursor/create_plan",
                text=_create_plan_text(params),
                name=params.get("name"),
                overview=params.get("overview"),
                todos=params.get("todos"),
                tool_call_id=params.get("toolCallId"),
                raw=message,
            )
        )
        self._send_response(message.get("id"), {"accepted": True})

    def _handle_unsupported_request(self, message: dict[str, Any]) -> None:
        method = str(message.get("method") or "")
        self.on_event(event("unsupported_acp_request", source="cursor_acp", method=method, raw=message))
        self._send_error(message.get("id"), code=-32601, message=f"Unsupported ACP client method: {method}")

    def _send_response(self, request_id: Any, result: Any) -> None:
        if self.proc is None or self.proc.stdin is None:
            return
        response = {"jsonrpc": "2.0", "id": request_id, "result": result}
        self.proc.stdin.write(json.dumps(response, ensure_ascii=False) + "\n")
        self.proc.stdin.flush()

    def _send_error(self, request_id: Any, *, code: int, message: str) -> None:
        if self.proc is None or self.proc.stdin is None:
            return
        response = {"jsonrpc": "2.0", "id": request_id, "error": {"code": code, "message": message}}
        self.proc.stdin.write(json.dumps(response, ensure_ascii=False) + "\n")
        self.proc.stdin.flush()

    def _next_id(self) -> int:
        self._ids += 1
        return self._ids

    def _start_stdout_reader(self) -> None:
        assert self.proc is not None
        pipe = self.proc.stdout
        if pipe is None:
            self._stdout_q.put(None)
            return

        def _read() -> None:
            try:
                for line in pipe:
                    self._stdout_q.put(line)
            finally:
                self._stdout_q.put(None)

        threading.Thread(target=_read, daemon=True).start()

    def _start_stderr_reader(self) -> None:
        assert self.proc is not None
        pipe = self.proc.stderr
        if pipe is None:
            return

        def _read() -> None:
            try:
                for line in pipe:
                    self._stderr_q.put(line)
            finally:
                self._stderr_q.put(None)

        threading.Thread(target=_read, daemon=True).start()

    def _drain_stderr(self) -> None:
        while True:
            try:
                line = self._stderr_q.get_nowait()
            except queue.Empty:
                return
            if line is None:
                return
            self.on_event(event("diagnostic", source="acp_stderr", text=line.rstrip()))


def run_acp_turn(
    *,
    cfg: HarnessConfig,
    store: HarnessStore,
    record: SessionRecord,
    prompt: str,
    timeout_sec: float | None = None,
    event_callback: Callable[[dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    """Run one Cursor turn through ACP server mode."""

    start = time.time()
    all_events: list[dict[str, Any]] = []

    def on_event(item: dict[str, Any]) -> None:
        stored = store.append_event(record.harness_session_id, item)
        all_events.append(stored)
        _notify_event(event_callback, stored)
        if stored.get("cursor_session_id"):
            record.cursor_session_id = stored.get("cursor_session_id")

    client = AcpClient(
        command=resolve_acp_command(cfg),
        cwd=record.project_path,
        permission_policy=record.permission_policy,
        on_event=on_event,
        trusted_readonly_mcp_tools=cfg.trusted_readonly_mcp_tools,
        approval_bridge_command=cfg.approval_bridge_command,
        approval_bridge_timeout_sec=cfg.approval_bridge_timeout_sec,
    )
    record.status = "running"
    store.upsert(record)
    try:
        client.start()
        init = client.initialize(timeout_sec=30) or {}
        on_event(event("session_started", source="cursor_acp", agent_info=init.get("agentInfo"), raw=init))
        cursor_session_id = _open_session(client, cfg, record, timeout_sec=30)
        record.cursor_session_id = cursor_session_id
        store.upsert(record)
        _maybe_set_mode(client, record)
        result = client.request(
            "session/prompt",
            {"sessionId": cursor_session_id, "prompt": [{"type": "text", "text": prompt}]},
            timeout_sec=timeout_sec or cfg.default_timeout_sec,
        )
        stop_reason = (result or {}).get("stopReason")
        assistant_text = "".join(
            str(item.get("text") or "")
            for item in all_events
            if item.get("type") == "message_delta" and item.get("role") == "assistant"
        )
        plan_text = "\n\n".join(str(item.get("text") or "") for item in all_events if item.get("type") == "plan" and item.get("text"))
        text = "\n\n".join(item for item in [assistant_text, plan_text] if item.strip())
        record.status = "idle"
        record.last_result = text
        record.last_stop_reason = stop_reason
        record.last_error = None
        store.upsert(record)
        return {
            "success": stop_reason in SUCCESS_STOP_REASONS,
            "transport": "acp",
            "harness_session_id": record.harness_session_id,
            "cursor_session_id": record.cursor_session_id,
            "text": text,
            "stop_reason": stop_reason,
            "duration_ms": int((time.time() - start) * 1000),
            "modified_files": modified_files_from_events(all_events),
            "events": all_events,
        }
    except Exception as exc:
        record.status = "failed"
        record.last_error = str(exc)
        store.upsert(record)
        raise
    finally:
        client.close()


def _open_session(client: AcpClient, cfg: HarnessConfig, record: SessionRecord, timeout_sec: float) -> str:
    params = {"cwd": record.project_path, "mcpServers": cfg.mcp_servers}
    caps = client.capabilities or {}
    session_caps = caps.get("sessionCapabilities") or {}
    if record.cursor_session_id and session_caps.get("resume") is not None:
        result = client.request("session/resume", {"sessionId": record.cursor_session_id, **params}, timeout_sec=timeout_sec)
        return str((result or {}).get("sessionId") or record.cursor_session_id)
    if record.cursor_session_id and caps.get("loadSession"):
        result = client.request("session/load", {"sessionId": record.cursor_session_id, **params}, timeout_sec=timeout_sec)
        return str((result or {}).get("sessionId") or record.cursor_session_id)
    result = client.request("session/new", params, timeout_sec=timeout_sec)
    session_id = (result or {}).get("sessionId")
    if not session_id:
        raise AcpError("session/new did not return sessionId")
    return str(session_id)


def _create_plan_text(params: dict[str, Any]) -> str:
    plan = params.get("plan")
    if isinstance(plan, str) and plan.strip():
        return plan
    parts: list[str] = []
    name = params.get("name")
    overview = params.get("overview")
    if isinstance(name, str) and name.strip():
        parts.append(f"# {name.strip()}")
    if isinstance(overview, str) and overview.strip():
        parts.append(overview.strip())
    todos = params.get("todos")
    if isinstance(todos, list):
        todo_lines: list[str] = []
        for todo in todos:
            if isinstance(todo, str) and todo.strip():
                todo_lines.append(f"- {todo.strip()}")
            elif isinstance(todo, dict):
                text = todo.get("content") or todo.get("text") or todo.get("title")
                if isinstance(text, str) and text.strip():
                    todo_lines.append(f"- {text.strip()}")
        if todo_lines:
            parts.append("\n".join(todo_lines))
    return "\n\n".join(parts)


def _maybe_set_mode(client: AcpClient, record: SessionRecord) -> None:
    mode_map = {"plan": "plan", "ask": "ask", "edit": "edit", "full_access": "edit"}
    mode_id = mode_map.get(record.permission_policy)
    if not mode_id:
        return
    try:
        client.request("session/set_mode", {"sessionId": record.cursor_session_id, "modeId": mode_id}, timeout_sec=10)
    except Exception as exc:
        client.on_event(event("diagnostic", source="cursor_acp", text=f"session/set_mode ignored: {exc}"))


def _notify_event(callback: Callable[[dict[str, Any]], None] | None, item: dict[str, Any]) -> None:
    if callback is None:
        return
    try:
        callback(item)
    except Exception:
        pass
