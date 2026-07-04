#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
import time


def emit(payload: dict) -> None:
    print(json.dumps(payload), flush=True)


def main() -> int:
    payload = json.loads(sys.stdin.read() or "{}")
    action = payload.get("action") or "run"
    if os.environ.get("FAKE_SDK_FAIL_BEFORE_SESSION"):
        emit({"type": "error", "error": "fake sdk startup failure"})
        return 1
    if action == "status":
        emit({"type": "status", "success": True, "sdk_version": "fake"})
        return 0
    if action == "models":
        emit({"type": "data", "action": "models", "result": [{"id": "composer-2", "displayName": "Composer 2"}]})
        return 0
    if action != "run":
        emit({"type": "data", "action": action, "result": {"ok": True}})
        return 0
    agent_id = payload.get("agent_id") or "sdk_agent_test"
    run_id = "sdk_run_test"
    emit({"type": "agent", "agent_id": agent_id, "runtime": payload.get("runtime") or "local", "resumed": bool(payload.get("agent_id"))})
    emit({"type": "run", "agent_id": agent_id, "run_id": run_id, "status": "running"})
    emit(
        {
            "type": "sdk_event",
            "message": {
                "type": "system",
                "agent_id": agent_id,
                "run_id": run_id,
                "model": {"id": payload.get("model") or "composer-2"},
                "tools": ["edit_file"],
            },
        }
    )
    emit(
        {
            "type": "sdk_event",
            "message": {
                "type": "assistant",
                "agent_id": agent_id,
                "run_id": run_id,
                "message": {"role": "assistant", "content": [{"type": "text", "text": "sdk hello"}]},
            },
        }
    )
    emit(
        {
            "type": "sdk_event",
            "message": {
                "type": "tool_call",
                "agent_id": agent_id,
                "run_id": run_id,
                "call_id": "call_1",
                "name": "edit_file",
                "status": "completed",
                "args": {"path": "README.md"},
            },
        }
    )
    if os.environ.get("FAKE_SDK_DELAY"):
        time.sleep(float(os.environ["FAKE_SDK_DELAY"]))
    emit(
        {
            "type": "result",
            "agent_id": agent_id,
            "run_id": run_id,
            "status": "finished",
            "result": "" if os.environ.get("FAKE_SDK_EMPTY_RESULT") else "sdk done",
            "model": {"id": "composer-2"},
            "duration_ms": 7,
        }
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
