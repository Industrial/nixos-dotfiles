"""Cursor Agent stream-json transport."""

from __future__ import annotations

import json
import os
import queue
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path
from collections.abc import Callable
from typing import Any

from .child_env import cursor_child_env
from .config import HarnessConfig, resolve_stream_command
from .events import event, modified_files_from_events, normalize_stream_json
from .store import HarnessStore, SessionRecord


def run_stream_turn(
    *,
    cfg: HarnessConfig,
    store: HarnessStore,
    record: SessionRecord,
    prompt: str,
    timeout_sec: float | None = None,
    event_callback: Callable[[dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    """Run one Cursor Agent turn through the stream-json CLI."""

    command = resolve_stream_command(cfg)
    args = _build_args(record=record, prompt=prompt)
    argv = command + args
    start = time.time()
    all_events: list[dict[str, Any]] = []

    popen_kwargs: dict[str, Any] = {
        "stdin": subprocess.DEVNULL,
        "stdout": subprocess.PIPE,
        "stderr": subprocess.PIPE,
        "cwd": record.project_path,
        "text": True,
        "encoding": "utf-8",
        "errors": "replace",
        "bufsize": 1,
        "env": cursor_child_env(include_test_controls=True),
    }
    if sys.platform == "win32":
        popen_kwargs["creationflags"] = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    else:
        popen_kwargs["preexec_fn"] = os.setsid  # type: ignore[assignment]

    record.status = "running"
    store.upsert(record)
    try:
        proc = subprocess.Popen(argv, **popen_kwargs)
    except Exception as exc:
        record.status = "failed"
        record.last_error = str(exc)
        store.upsert(record)
        raise

    q: queue.Queue[tuple[str, str | None]] = queue.Queue()
    _start_reader(proc.stdout, "stdout", q)
    _start_reader(proc.stderr, "stderr", q)

    deadline = start + (timeout_sec or cfg.default_timeout_sec)
    no_output_deadline = time.time() + cfg.no_output_timeout_sec
    open_streams = {"stdout", "stderr"}
    result_text = ""
    success = False
    error: str | None = None

    try:
        while open_streams:
            if time.time() > deadline:
                error = f"timeout after {timeout_sec or cfg.default_timeout_sec}s"
                _terminate(proc)
                break
            if time.time() > no_output_deadline:
                error = f"no output for {cfg.no_output_timeout_sec}s"
                _terminate(proc)
                break
            try:
                source, line = q.get(timeout=0.25)
            except queue.Empty:
                continue
            if line is None:
                open_streams.discard(source)
                continue
            no_output_deadline = time.time() + cfg.no_output_timeout_sec
            try:
                raw = json.loads(line)
            except json.JSONDecodeError:
                item = store.append_event(record.harness_session_id, event("diagnostic", source=source, text=line.rstrip()))
                all_events.append(item)
                _notify_event(event_callback, item)
                continue
            for normalized in normalize_stream_json(raw):
                item = store.append_event(record.harness_session_id, normalized)
                all_events.append(item)
                _notify_event(event_callback, item)
                if item.get("cursor_session_id"):
                    record.cursor_session_id = item.get("cursor_session_id")
                if item.get("type") == "turn_result":
                    result_text = str(item.get("text") or "")
                    success = bool(item.get("success"))
                    record.last_result = result_text
                    record.last_stop_reason = "end_turn" if success else "error"
    finally:
        if proc.poll() is None:
            _terminate(proc)
        _wait_or_kill(proc)

    if error:
        success = False
        record.last_error = error
    elif proc.returncode not in (0, None) and not success:
        error = f"cursor-agent exited with {proc.returncode}"
        record.last_error = error
    else:
        record.last_error = None

    record.status = "idle" if success else "failed"
    store.upsert(record)
    return {
        "success": success,
        "transport": "stream",
        "harness_session_id": record.harness_session_id,
        "cursor_session_id": record.cursor_session_id,
        "text": result_text,
        "error": error,
        "duration_ms": int((time.time() - start) * 1000),
        "modified_files": modified_files_from_events(all_events),
        "events": all_events,
    }


def _build_args(*, record: SessionRecord, prompt: str) -> list[str]:
    args = ["-p", "--trust", "--output-format", "stream-json"]
    if record.cursor_session_id:
        args.extend(["--resume", record.cursor_session_id])
    if record.model:
        args.extend(["--model", record.model])
    if record.permission_policy in {"plan", "ask", "reject"}:
        cursor_mode = "ask" if record.permission_policy == "ask" else "plan"
        args.extend(["--mode", cursor_mode])
    if record.permission_policy == "full_access":
        args.append("--force")
        args.append("--approve-mcps")
    args.append(prompt)
    return args


def _start_reader(pipe: Any, source: str, q: queue.Queue[tuple[str, str | None]]) -> None:
    if pipe is None:
        q.put((source, None))
        return

    def _read() -> None:
        try:
            for line in pipe:
                q.put((source, line))
        finally:
            q.put((source, None))

    threading.Thread(target=_read, daemon=True).start()


def _terminate(proc: subprocess.Popen[str]) -> None:
    if proc.poll() is not None:
        return
    try:
        if sys.platform == "win32":
            proc.terminate()
        else:
            os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
    except Exception:
        proc.terminate()


def _wait_or_kill(proc: subprocess.Popen[str]) -> None:
    try:
        proc.wait(timeout=5)
        return
    except subprocess.TimeoutExpired:
        pass
    try:
        if sys.platform == "win32":
            proc.kill()
        else:
            os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
    except Exception:
        proc.kill()
    proc.wait(timeout=5)


def _notify_event(callback: Callable[[dict[str, Any]], None] | None, item: dict[str, Any]) -> None:
    if callback is None:
        return
    try:
        callback(item)
    except Exception:
        pass
