#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys


def send(payload: dict) -> None:
    print(json.dumps(payload), flush=True)


def read_response() -> dict:
    return json.loads(sys.stdin.readline())


def main() -> int:
    session_id = "cur_acp_test"
    for line in sys.stdin:
        if not line.strip():
            continue
        message = json.loads(line)
        request_id = message.get("id")
        method = message.get("method")
        if method == "initialize":
            send(
                {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "result": {
                        "protocolVersion": 1,
                        "agentCapabilities": {
                            "loadSession": True,
                            "sessionCapabilities": {"resume": {}, "close": {}},
                        },
                        "agentInfo": {"name": "fake-cursor-acp", "version": "0.1"},
                        "authMethods": [],
                    },
                }
            )
        elif method == "session/new":
            send({"jsonrpc": "2.0", "id": request_id, "result": {"sessionId": session_id}})
        elif method == "session/resume":
            send({"jsonrpc": "2.0", "id": request_id, "result": {"sessionId": message["params"]["sessionId"]}})
        elif method == "session/set_mode":
            send({"jsonrpc": "2.0", "id": request_id, "result": {}})
        elif method == "session/prompt":
            prompt_text = "".join(
                item.get("text", "")
                for item in (message.get("params") or {}).get("prompt", [])
                if isinstance(item, dict)
            )
            if os.environ.get("FAKE_ACP_PERMISSION") == "1":
                send(
                    {
                        "jsonrpc": "2.0",
                        "id": "perm_1",
                        "method": "session/request_permission",
                        "params": {
                            "sessionId": session_id,
                            "toolCall": {"toolCallId": "call_needs_permission", "title": "edit"},
                            "options": [
                                {"optionId": "allow_once_id", "kind": "allow_once", "name": "Allow once"},
                                {"optionId": "reject_once_id", "kind": "reject_once", "name": "Reject once"},
                            ],
                        },
                    }
                )
                permission_response = read_response()
                outcome = permission_response.get("result", {}).get("outcome", {})
                if outcome.get("outcome") != "selected" or outcome.get("optionId") != "allow_once_id":
                    send(
                        {
                            "jsonrpc": "2.0",
                            "id": request_id,
                            "error": {"code": -32000, "message": f"bad permission outcome: {outcome}"},
                        }
                    )
                    continue
            if os.environ.get("FAKE_ACP_HERMES_MCP_PERMISSION") == "1":
                send(
                    {
                        "jsonrpc": "2.0",
                        "id": "perm_mcp_1",
                        "method": "session/request_permission",
                        "params": {
                            "sessionId": session_id,
                            "toolCall": {
                                "toolCallId": "call_mcp_status",
                                "kind": "other",
                                "title": "hermes-cursor-harness-hermes_cursor_status: hermes_cursor_status",
                            },
                            "options": [
                                {"optionId": "allow-once", "kind": "allow_once", "name": "Allow once"},
                                {"optionId": "allow-always", "kind": "allow_always", "name": "Allow always"},
                                {"optionId": "reject-once", "kind": "reject_once", "name": "Reject"},
                            ],
                        },
                    }
                )
                permission_response = read_response()
                outcome = permission_response.get("result", {}).get("outcome", {})
                if outcome.get("outcome") != "selected" or outcome.get("optionId") != "allow-once":
                    send(
                        {
                            "jsonrpc": "2.0",
                            "id": request_id,
                            "error": {"code": -32000, "message": f"bad mcp permission outcome: {outcome}"},
                        }
                    )
                    continue
            if os.environ.get("FAKE_ACP_UNSUPPORTED") == "1":
                send(
                    {
                        "jsonrpc": "2.0",
                        "id": "unsupported_1",
                        "method": "terminal/create",
                        "params": {"cwd": os.getcwd()},
                    }
                )
                unsupported_response = read_response()
                if unsupported_response.get("error", {}).get("code") != -32601:
                    send(
                        {
                            "jsonrpc": "2.0",
                            "id": request_id,
                            "error": {"code": -32000, "message": f"bad unsupported response: {unsupported_response}"},
                        }
                    )
                    continue
            send(
                {
                    "jsonrpc": "2.0",
                    "method": "session/update",
                    "params": {
                        "sessionId": session_id,
                        "update": {
                            "sessionUpdate": "agent_message_chunk",
                            "content": {"type": "text", "text": "acp hello"},
                        },
                    },
                }
            )
            if os.environ.get("FAKE_NO_TOOL_CALL") != "1":
                send(
                    {
                        "jsonrpc": "2.0",
                        "method": "session/update",
                        "params": {
                            "sessionId": session_id,
                            "update": {
                                "sessionUpdate": "tool_call",
                                "toolCall": {"toolCallId": "call_acp", "title": "edit", "path": "src/app.py"},
                            },
                        },
                    }
                )
            if os.environ.get("FAKE_ACP_ECHO_PROMPT") == "1" and prompt_text:
                send(
                    {
                        "jsonrpc": "2.0",
                        "method": "session/update",
                        "params": {
                            "sessionId": session_id,
                            "update": {
                                "sessionUpdate": "agent_message_chunk",
                                "content": {"type": "text", "text": prompt_text},
                            },
                        },
                    }
                )
            if os.environ.get("FAKE_ACP_CREATE_PLAN") == "1":
                send(
                    {
                        "jsonrpc": "2.0",
                        "id": "plan_1",
                        "method": "cursor/create_plan",
                        "params": {
                            "name": "Fake ACP plan",
                            "overview": "Verify ACP plan capture.",
                            "plan": f"# Fake ACP plan\n\n{prompt_text}",
                            "todos": [{"content": "Keep the smoke read-only", "status": "pending"}],
                            "toolCallId": "call_create_plan",
                        },
                    }
                )
                plan_response = read_response()
                if "error" in plan_response:
                    send(
                        {
                            "jsonrpc": "2.0",
                            "id": request_id,
                            "error": {"code": -32000, "message": f"bad create plan response: {plan_response}"},
                        }
                    )
                    continue
            send({"jsonrpc": "2.0", "id": request_id, "result": {"stopReason": "end_turn"}})
        else:
            send({"jsonrpc": "2.0", "id": request_id, "error": {"code": -32601, "message": f"unknown {method}"}})
    return 0


if __name__ == "__main__":
    os.chdir(os.getcwd())
    raise SystemExit(main())
