"""Cursor SDK transport.

This is the deepest public integration surface Cursor currently exposes:
Hermes owns the outer session/tool/permission layer, while @cursor/sdk owns the
Cursor-native agent runtime, model selection, MCP/skills/hooks/subagent loading,
local or cloud execution, and resumable agent state.
"""

from __future__ import annotations

import json
import os
import queue
import signal
import shutil
import subprocess
import sys
import threading
import time
from collections.abc import Callable
from pathlib import Path
from typing import Any

from .child_env import cursor_child_env
from .config import HarnessConfig, resolve_sdk_command
from .credentials import resolve_background_api_key
from .events import event, modified_files_from_events, normalize_sdk_json
from .store import HarnessStore, SessionRecord


def run_sdk_turn(
    *,
    cfg: HarnessConfig,
    store: HarnessStore,
    record: SessionRecord,
    prompt: str,
    timeout_sec: float | None = None,
    event_callback: Callable[[dict[str, Any]], None] | None = None,
) -> dict[str, Any]:
    """Run one Cursor turn through @cursor/sdk."""

    if cfg.sdk_runtime == "cloud" and not (resolve_background_api_key() or os.environ.get("CURSOR_API_KEY")):
        raise ValueError("Cursor SDK cloud runtime requires CURSOR_API_KEY or a configured cursor-background-api-key")
    if not cfg.sdk_command and cfg.sdk_auto_install:
        ensure_sdk_package(cfg)
    command = resolve_sdk_command(cfg)
    payload = _sdk_payload(cfg=cfg, record=record, prompt=prompt)
    start = time.time()
    all_events: list[dict[str, Any]] = []

    popen_kwargs: dict[str, Any] = {
        "stdin": subprocess.PIPE,
        "stdout": subprocess.PIPE,
        "stderr": subprocess.PIPE,
        "cwd": record.project_path,
        "text": True,
        "encoding": "utf-8",
        "errors": "replace",
        "bufsize": 1,
        "env": _sdk_env(cfg),
    }
    if sys.platform == "win32":
        popen_kwargs["creationflags"] = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    else:
        popen_kwargs["preexec_fn"] = os.setsid  # type: ignore[assignment]

    record.status = "running"
    store.upsert(record)
    try:
        proc = subprocess.Popen(command, **popen_kwargs)
        assert proc.stdin is not None
        proc.stdin.write(json.dumps(payload, ensure_ascii=False) + "\n")
        proc.stdin.close()
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
    assistant_text_parts: list[str] = []
    success = False
    error: str | None = None
    sdk_run_id: str | None = None

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
            if source == "stderr":
                item = store.append_event(record.harness_session_id, event("diagnostic", source="cursor_sdk_stderr", text=line.rstrip()))
                all_events.append(item)
                _notify_event(event_callback, item)
                continue
            try:
                raw = json.loads(line)
            except json.JSONDecodeError:
                item = store.append_event(record.harness_session_id, event("diagnostic", source="cursor_sdk_stdout", text=line.rstrip()))
                all_events.append(item)
                _notify_event(event_callback, item)
                continue
            for normalized in normalize_sdk_json(raw):
                item = store.append_event(record.harness_session_id, normalized)
                all_events.append(item)
                _notify_event(event_callback, item)
                if item.get("type") == "message_delta" and item.get("role") == "assistant":
                    assistant_text_parts.append(str(item.get("text") or ""))
                if item.get("cursor_session_id"):
                    record.cursor_session_id = item.get("cursor_session_id")
                if item.get("sdk_run_id"):
                    sdk_run_id = str(item.get("sdk_run_id"))
                    record.last_sdk_run_id = sdk_run_id
                if item.get("type") == "turn_result":
                    result_text = str(item.get("text") or "") or "".join(assistant_text_parts)
                    success = bool(item.get("success"))
                    error = str(item.get("error")) if item.get("error") else error
                    record.last_result = result_text
                    record.last_stop_reason = str(item.get("status") or ("finished" if success else "error"))
    finally:
        if proc.poll() is None:
            _terminate(proc)
        _wait_or_kill(proc)

    if error:
        success = False
        record.last_error = error
    elif proc.returncode not in (0, None) and not success:
        error = f"cursor SDK bridge exited with {proc.returncode}"
        record.last_error = error
    else:
        record.last_error = None

    record.status = "idle" if success else "failed"
    store.upsert(record)
    return {
        "success": success,
        "transport": "sdk",
        "sdk_runtime": cfg.sdk_runtime,
        "harness_session_id": record.harness_session_id,
        "cursor_session_id": record.cursor_session_id,
        "sdk_run_id": sdk_run_id,
        "text": result_text,
        "error": error,
        "duration_ms": int((time.time() - start) * 1000),
        "modified_files": modified_files_from_events(all_events),
        "events": all_events,
    }


def sdk_status(cfg: HarnessConfig, *, timeout_sec: float = 30.0, install: bool = False) -> dict[str, Any]:
    """Check that the SDK bridge and package can be loaded."""

    try:
        if install and not cfg.sdk_command and cfg.sdk_auto_install:
            ensure_sdk_package(cfg)
        return _run_sdk_action(cfg, {"action": "status"}, timeout_sec=timeout_sec)
    except Exception as exc:
        return {"success": False, "error": str(exc)}


def sdk_catalog_action(cfg: HarnessConfig, action: str, *, timeout_sec: float = 45.0, install: bool = False) -> dict[str, Any]:
    """Run a Cursor SDK account/catalog action such as models or me."""

    if install and not cfg.sdk_command and cfg.sdk_auto_install:
        ensure_sdk_package(cfg)
    payload = {"action": action, "api_key": resolve_background_api_key()}
    return _run_sdk_action(cfg, payload, timeout_sec=timeout_sec)


def ensure_sdk_package(cfg: HarnessConfig) -> Path:
    """Install @cursor/sdk into the harness state directory if needed."""

    node_dir = sdk_node_dir(cfg)
    package_json = node_dir / "node_modules" / "@cursor" / "sdk" / "package.json"
    if package_json.exists():
        return node_dir / "node_modules"
    npm = shutil.which("npm")
    if not npm:
        raise FileNotFoundError("npm is required to install @cursor/sdk; set sdk_command to a preconfigured bridge instead")
    node_dir.mkdir(parents=True, exist_ok=True)
    if not (node_dir / "package.json").exists():
        (node_dir / "package.json").write_text(
            json.dumps({"private": True, "dependencies": {}}, indent=2) + "\n",
            encoding="utf-8",
        )
    proc = subprocess.run(
        [npm, "install", "--silent", "--no-audit", "--no-fund", cfg.sdk_package],
        cwd=str(node_dir),
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=180,
        check=False,
        env=cursor_child_env(include_cursor_credentials=False),
    )
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout or "").strip()
        raise RuntimeError(f"npm install {cfg.sdk_package} failed with {proc.returncode}: {detail}")
    return node_dir / "node_modules"


def sdk_node_dir(cfg: HarnessConfig) -> Path:
    return (cfg.sdk_node_dir or (cfg.state_dir / "sdk-node")).expanduser()


def _run_sdk_action(cfg: HarnessConfig, payload: dict[str, Any], *, timeout_sec: float) -> dict[str, Any]:
    command = resolve_sdk_command(cfg)
    proc = subprocess.run(
        command,
        input=json.dumps(payload, ensure_ascii=False) + "\n",
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout_sec,
        check=False,
        env=_sdk_env(cfg),
    )
    rows: list[dict[str, Any]] = []
    for line in proc.stdout.splitlines():
        if not line.strip():
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            rows.append({"type": "diagnostic", "text": line})
    error_row = next((row for row in rows if row.get("type") == "error"), None)
    data_row = next((row for row in rows if row.get("type") in {"data", "status"}), None)
    success = proc.returncode == 0 and error_row is None
    result = {"success": success, "command": command, "rows": rows, "stderr": proc.stderr}
    if data_row:
        result.update({key: value for key, value in data_row.items() if key != "type"})
    if error_row:
        result["error"] = error_row.get("error")
    elif proc.returncode != 0:
        result["error"] = f"cursor SDK bridge exited with {proc.returncode}"
    return result


def _sdk_payload(*, cfg: HarnessConfig, record: SessionRecord, prompt: str) -> dict[str, Any]:
    cloud_repository = cfg.sdk_cloud_repository or _discover_git_remote(record.project_path)
    payload: dict[str, Any] = {
        "action": "run",
        "runtime": cfg.sdk_runtime,
        "project_path": record.project_path,
        "prompt": prompt,
        "agent_id": record.cursor_session_id,
        "model": record.model or cfg.default_model,
        "permission_policy": record.permission_policy,
        "mcp_servers": cfg.mcp_servers,
        "api_key": resolve_background_api_key(),
        "setting_sources": cfg.sdk_setting_sources,
        "sandbox_enabled": cfg.sdk_sandbox_enabled,
        "cloud_repository": cloud_repository,
        "cloud_ref": cfg.sdk_cloud_ref,
        "auto_create_pr": cfg.sdk_auto_create_pr,
    }
    return {key: value for key, value in payload.items() if value not in (None, "", [])}


def _sdk_env(cfg: HarnessConfig) -> dict[str, str]:
    extra: dict[str, str] = {}
    node_modules = sdk_node_dir(cfg) / "node_modules"
    if node_modules.exists():
        extra["HERMES_CURSOR_HARNESS_SDK_NODE_MODULES"] = str(node_modules)
    api_key = resolve_background_api_key()
    env = cursor_child_env(extra=extra, include_test_controls=True)
    if api_key:
        env["CURSOR_API_KEY"] = api_key
        env["CURSOR_BACKGROUND_API_KEY"] = api_key
    return env


def _discover_git_remote(project_path: str) -> str | None:
    git = shutil.which("git")
    if not git:
        return None
    try:
        proc = subprocess.run(
            [git, "config", "--get", "remote.origin.url"],
            cwd=project_path,
            text=True,
            encoding="utf-8",
            errors="replace",
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=5,
            check=False,
        )
    except Exception:
        return None
    value = proc.stdout.strip()
    if proc.returncode != 0 or not value:
        return None
    return _normalize_git_url(value)


def _normalize_git_url(value: str) -> str:
    if value.startswith("git@github.com:"):
        return "https://github.com/" + value.split(":", 1)[1].removesuffix(".git")
    return value


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
