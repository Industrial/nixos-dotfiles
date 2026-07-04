from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

from hermes_cursor_harness.config import HarnessConfig
from hermes_cursor_harness.store import HarnessStore, SessionRecord


def test_mcp_server_lists_tools_and_status(tmp_path: Path) -> None:
    project = tmp_path / "project"
    project.mkdir()
    config_path = tmp_path / "cursor_harness.json"
    state_dir = tmp_path / "state"
    config_path.write_text(
        json.dumps({"projects": {"demo": str(project)}, "state_dir": str(state_dir)}),
        encoding="utf-8",
    )
    cfg = HarnessConfig(projects={"demo": str(project)}, state_dir=state_dir)
    store = HarnessStore(cfg.state_dir)
    record = SessionRecord.new(
        project_path=str(project),
        transport="acp",
        mode="plan",
        model=None,
        permission_policy="plan",
    )
    store.upsert(record)

    requests = [
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
        {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "hermes_cursor_status", "arguments": {}}},
        {
            "jsonrpc": "2.0",
            "id": 4,
            "method": "tools/call",
            "params": {"name": "hermes_cursor_project_context", "arguments": {"project": "demo"}},
        },
    ]
    proc = subprocess.run(
        [sys.executable, "-m", "hermes_cursor_harness.mcp_server"],
        input="".join(json.dumps(item) + "\n" for item in requests),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env={"PYTHONPATH": str(Path(__file__).parents[1]), "HERMES_CURSOR_HARNESS_CONFIG": str(config_path)},
        timeout=10,
        check=False,
    )

    assert proc.returncode == 0, proc.stderr
    responses = [json.loads(line) for line in proc.stdout.splitlines()]
    assert responses[0]["result"]["serverInfo"]["name"] == "hermes-cursor-harness"
    assert any(tool["name"] == "hermes_cursor_status" for tool in responses[1]["result"]["tools"])
    status_payload = json.loads(responses[2]["result"]["content"][0]["text"])
    assert status_payload["sessions"][0]["harness_session_id"] == record.harness_session_id
    context_payload = json.loads(responses[3]["result"]["content"][0]["text"])
    assert context_payload["permission_context"]["default_permission_policy"] == "plan"


def test_mcp_server_accepts_cursor_events_and_proposals(tmp_path: Path) -> None:
    project = tmp_path / "project"
    project.mkdir()
    config_path = tmp_path / "cursor_harness.json"
    state_dir = tmp_path / "state"
    config_path.write_text(
        json.dumps({"projects": {"demo": str(project)}, "state_dir": str(state_dir)}),
        encoding="utf-8",
    )
    cfg = HarnessConfig(projects={"demo": str(project)}, state_dir=state_dir)
    store = HarnessStore(cfg.state_dir)
    record = SessionRecord.new(
        project_path=str(project),
        transport="sdk",
        mode="plan",
        model="cursor/default",
        permission_policy="plan",
    )
    record.cursor_session_id = "cur_123"
    store.upsert(record)

    requests = [
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {
                "name": "hermes_cursor_append_event",
                "arguments": {
                    "harness_session_id": record.harness_session_id,
                    "event_type": "progress",
                    "text": "Cursor finished the repo scan.",
                    "payload": {"files": ["README.md"]},
                },
            },
        },
        {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": "hermes_cursor_propose",
                "arguments": {
                    "kind": "task_update",
                    "title": "Run focused tests",
                    "body": "The changed files suggest running the unit test lane.",
                    "priority": "high",
                    "harness_session_id": record.harness_session_id,
                    "source": "spoofed-hermes",
                },
            },
        },
        {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": {"name": "hermes_cursor_events", "arguments": {"harness_session_id": record.harness_session_id}},
        },
    ]
    proc = subprocess.run(
        [sys.executable, "-m", "hermes_cursor_harness.mcp_server"],
        input="".join(json.dumps(item) + "\n" for item in requests),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env={"PYTHONPATH": str(Path(__file__).parents[1]), "HERMES_CURSOR_HARNESS_CONFIG": str(config_path)},
        timeout=10,
        check=False,
    )

    assert proc.returncode == 0, proc.stderr
    responses = [json.loads(line) for line in proc.stdout.splitlines()]
    appended = json.loads(responses[0]["result"]["content"][0]["text"])
    proposed = json.loads(responses[1]["result"]["content"][0]["text"])
    events = json.loads(responses[2]["result"]["content"][0]["text"])["events"]

    assert appended["success"] is True
    assert appended["event"]["type"] == "cursor_companion_event"
    assert appended["event"]["source"] == "cursor_mcp"
    assert proposed["success"] is True
    assert proposed["proposal"]["status"] == "pending"
    assert proposed["proposal"]["source"] == "cursor_mcp"
    assert proposed["proposal"]["cursor_session_id"] == "cur_123"
    assert [item["type"] for item in events] == ["cursor_companion_event", "cursor_companion_proposal"]


def test_mcp_server_rejects_unknown_session_for_cursor_event(tmp_path: Path) -> None:
    config_path = tmp_path / "cursor_harness.json"
    config_path.write_text(json.dumps({"state_dir": str(tmp_path / "state")}), encoding="utf-8")
    request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": "hermes_cursor_append_event",
            "arguments": {"harness_session_id": "missing", "text": "hello"},
        },
    }

    proc = subprocess.run(
        [sys.executable, "-m", "hermes_cursor_harness.mcp_server"],
        input=json.dumps(request) + "\n",
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env={"PYTHONPATH": str(Path(__file__).parents[1]), "HERMES_CURSOR_HARNESS_CONFIG": str(config_path)},
        timeout=10,
        check=False,
    )

    assert proc.returncode == 0, proc.stderr
    payload = json.loads(json.loads(proc.stdout)["result"]["content"][0]["text"])
    assert payload["success"] is False
    assert "unknown harness_session_id" in payload["error"]
