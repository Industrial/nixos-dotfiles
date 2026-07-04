#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
import time


def emit(payload: dict) -> None:
    stream = sys.stderr if os.environ.get("FAKE_STREAM_STDERR") == "1" else sys.stdout
    print(json.dumps(payload), file=stream, flush=True)


def main() -> int:
    if os.environ.get("FAKE_STREAM_NO_OUTPUT") == "1":
        time.sleep(float(os.environ.get("FAKE_STREAM_SLEEP", "10")))
        return 0
    prompt = sys.argv[-1] if sys.argv else ""
    if os.environ.get("EXPECT_CURSOR_TRUST") == "1" and "--trust" not in sys.argv:
        print("missing --trust", file=sys.stderr, flush=True)
        return 9
    expected_mode = os.environ.get("EXPECT_CURSOR_MODE")
    if expected_mode:
        try:
            mode = sys.argv[sys.argv.index("--mode") + 1]
        except (ValueError, IndexError):
            print("missing --mode", file=sys.stderr, flush=True)
            return 7
        if mode != expected_mode:
            print(f"expected --mode {expected_mode}, got {mode}", file=sys.stderr, flush=True)
            return 8
    cwd = os.getcwd()
    session_id = "cur_stream_test"
    emit({"type": "system", "subtype": "init", "session_id": session_id, "model": "cursor-test", "cwd": cwd})
    emit({"type": "user", "message": {"content": [{"type": "text", "text": prompt}]}, "session_id": session_id})
    emit({"type": "assistant", "message": {"content": [{"type": "text", "text": "stream hello"}]}, "session_id": session_id})
    if os.environ.get("FAKE_NO_TOOL_CALL") != "1":
        emit(
            {
                "type": "tool_call",
                "subtype": "completed",
                "call_id": "call_stream",
                "tool_call": {"writeToolCall": {"args": {"path": "README.md"}, "result": {"success": True}}},
                "session_id": session_id,
            }
        )
    time.sleep(0.01)
    result_text = prompt if os.environ.get("FAKE_STREAM_ECHO_PROMPT") == "1" else "stream done"
    emit({"type": "result", "subtype": "success", "result": result_text, "session_id": session_id, "duration_ms": 12})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
