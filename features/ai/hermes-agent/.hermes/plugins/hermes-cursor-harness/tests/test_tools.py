from __future__ import annotations

import json
from pathlib import Path

from hermes_cursor_harness.approval_queue import enqueue_approval_request
from hermes_cursor_harness.config import HarnessConfig
from hermes_cursor_harness.proposal_queue import enqueue_cursor_proposal
from hermes_cursor_harness.store import HarnessStore, SessionRecord
from hermes_cursor_harness.tools import (
    cursor_harness_approvals,
    cursor_harness_background_agent,
    cursor_harness_config,
    cursor_harness_proposal_inbox,
    cursor_harness_proposals,
    cursor_harness_status,
)


def test_tool_handlers_default_to_json_text(tmp_path: Path, monkeypatch) -> None:
    config_path = tmp_path / "cursor_harness.json"
    state_dir = tmp_path / "state"
    config_path.write_text(json.dumps({"state_dir": str(state_dir)}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))

    result = cursor_harness_status({})

    assert isinstance(result, str)
    payload = json.loads(result)
    assert payload["success"] is True
    assert payload["state_dir"] == str(state_dir)


def test_tool_handlers_can_return_structured_payload(tmp_path: Path, monkeypatch) -> None:
    config_path = tmp_path / "cursor_harness.json"
    state_dir = tmp_path / "state"
    config_path.write_text(json.dumps({"state_dir": str(state_dir)}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))

    result = cursor_harness_status({"as_dict": True})

    assert isinstance(result, dict)
    assert result["success"] is True
    assert result["state_dir"] == str(state_dir)


def test_tool_handlers_accept_structured_return_kwarg(tmp_path: Path, monkeypatch) -> None:
    config_path = tmp_path / "cursor_harness.json"
    state_dir = tmp_path / "state"
    config_path.write_text(json.dumps({"state_dir": str(state_dir)}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))

    result = cursor_harness_status({}, as_dict=True)

    assert isinstance(result, dict)
    assert result["success"] is True
    assert result["state_dir"] == str(state_dir)


def test_background_agent_tool_reports_missing_api_key(tmp_path: Path, monkeypatch) -> None:
    config_path = tmp_path / "cursor_harness.json"
    state_dir = tmp_path / "state"
    config_path.write_text(json.dumps({"state_dir": str(state_dir)}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))
    monkeypatch.delenv("CURSOR_BACKGROUND_API_KEY", raising=False)
    monkeypatch.delenv("CURSOR_API_KEY", raising=False)
    monkeypatch.setattr("hermes_cursor_harness.credentials.shutil.which", lambda name: None)

    result = cursor_harness_background_agent({"action": "list", "as_dict": True})

    assert isinstance(result, dict)
    assert result["success"] is False
    assert "API key is required" in result["error"]


def test_background_agent_tool_lists_local_records_without_api_key(tmp_path: Path, monkeypatch) -> None:
    config_path = tmp_path / "cursor_harness.json"
    state_dir = tmp_path / "state"
    config_path.write_text(json.dumps({"state_dir": str(state_dir)}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))
    monkeypatch.delenv("CURSOR_BACKGROUND_API_KEY", raising=False)
    monkeypatch.delenv("CURSOR_API_KEY", raising=False)
    HarnessStore(state_dir).record_background_agent({"id": "bg_1", "action": "sync_result"})

    result = cursor_harness_background_agent({"action": "local_list", "as_dict": True})

    assert isinstance(result, dict)
    assert result["success"] is True
    assert result["result"][0]["id"] == "bg_1"


def test_background_agent_local_list_is_allowed_under_readonly_profile(tmp_path: Path, monkeypatch) -> None:
    config_path = tmp_path / "cursor_harness.json"
    state_dir = tmp_path / "state"
    config_path.write_text(json.dumps({"state_dir": str(state_dir)}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))

    result = cursor_harness_background_agent({"action": "local_list", "security_profile": "readonly", "as_dict": True})

    assert isinstance(result, dict)
    assert result["success"] is True


def test_background_agent_remote_launch_requires_confirmation(tmp_path: Path, monkeypatch) -> None:
    config_path = tmp_path / "cursor_harness.json"
    state_dir = tmp_path / "state"
    config_path.write_text(json.dumps({"state_dir": str(state_dir)}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))

    result = cursor_harness_background_agent(
        {
            "action": "launch",
            "prompt": "Review the branch",
            "repository": "https://github.com/example/repo",
            "as_dict": True,
        }
    )

    assert isinstance(result, dict)
    assert result["success"] is False
    assert "confirm_remote=true" in result["error"]


def test_background_agent_delete_requires_delete_confirmation(tmp_path: Path, monkeypatch) -> None:
    config_path = tmp_path / "cursor_harness.json"
    state_dir = tmp_path / "state"
    config_path.write_text(json.dumps({"state_dir": str(state_dir)}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))

    result = cursor_harness_background_agent({"action": "delete", "agent_id": "bc_123", "as_dict": True})

    assert isinstance(result, dict)
    assert result["success"] is False
    assert "confirm_delete=true" in result["error"]


def test_background_agent_confirmed_delete_reaches_client(tmp_path: Path, monkeypatch) -> None:
    config_path = tmp_path / "cursor_harness.json"
    state_dir = tmp_path / "state"
    config_path.write_text(json.dumps({"state_dir": str(state_dir)}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))

    class FakeClient:
        def delete_agent(self, agent_id: str) -> dict[str, str]:
            return {"id": agent_id, "deleted": "true"}

    monkeypatch.setattr("hermes_cursor_harness.tools.client_from_config", lambda *_, **__: FakeClient())

    result = cursor_harness_background_agent(
        {
            "action": "delete",
            "agent_id": "bc_123",
            "confirm_delete": True,
            "as_dict": True,
        }
    )

    assert isinstance(result, dict)
    assert result["success"] is True
    assert result["result"] == {"id": "bc_123", "deleted": "true"}


def test_approval_tool_lists_and_decides_pending_requests(tmp_path: Path, monkeypatch) -> None:
    config_path = tmp_path / "cursor_harness.json"
    state_dir = tmp_path / "state"
    config_path.write_text(json.dumps({"state_dir": str(state_dir)}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))
    item = enqueue_approval_request(
        HarnessConfig(state_dir=state_dir),
        {
            "policy": "ask",
            "options": [{"optionId": "reject-once", "kind": "reject_once"}],
            "request": {"toolCall": {"title": "edit"}},
        },
    )

    listed = cursor_harness_approvals({"action": "list", "as_dict": True})
    decided = cursor_harness_approvals(
        {"action": "decide", "request_id": item["id"], "option_id": "reject-once", "as_dict": True}
    )

    assert isinstance(listed, dict)
    assert listed["approvals"][0]["id"] == item["id"]
    assert isinstance(decided, dict)
    assert decided["success"] is True
    assert decided["approval"]["status"] == "rejected"


def test_proposals_tool_lists_and_resolves_pending_requests(tmp_path: Path, monkeypatch) -> None:
    config_path = tmp_path / "cursor_harness.json"
    state_dir = tmp_path / "state"
    config_path.write_text(json.dumps({"state_dir": str(state_dir)}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))
    store = HarnessStore(state_dir)
    record = SessionRecord.new(
        project_path=str(tmp_path),
        transport="sdk",
        mode="plan",
        model=None,
        permission_policy="plan",
    )
    record.cursor_session_id = "cur_tool"
    store.upsert(record)
    item = enqueue_cursor_proposal(
        HarnessConfig(state_dir=state_dir),
        {
            "kind": "memory_update",
            "title": "Remember test command",
            "body": "The repo uses pytest -q for the quick lane.",
            "harness_session_id": record.harness_session_id,
            "cursor_session_id": record.cursor_session_id,
            "payload": {"command": "pytest -q"},
        },
    )

    listed = cursor_harness_proposals({"action": "list", "as_dict": True})
    inbox = cursor_harness_proposal_inbox({"as_dict": True})
    resolved = cursor_harness_proposals(
        {"action": "reject", "proposal_id": item["id"], "reason": "Covered elsewhere.", "as_dict": True}
    )

    assert isinstance(listed, dict)
    assert listed["proposals"][0]["id"] == item["id"]
    assert isinstance(inbox, dict)
    assert inbox["summary"]["pending"] == 1
    assert inbox["items"][0]["linked_events"] == []
    assert isinstance(resolved, dict)
    assert resolved["success"] is True
    assert resolved["proposal"]["status"] == "rejected"
    assert resolved["proposal"]["resolution"]["reason"] == "Covered elsewhere."
    assert resolved["resolution_event"]["type"] == "cursor_companion_proposal_resolution"
    assert store.read_events(record.harness_session_id)[0]["status"] == "rejected"


def test_config_tool_validates_current_config(tmp_path: Path, monkeypatch) -> None:
    config_path = tmp_path / "cursor_harness.json"
    state_dir = tmp_path / "state"
    fake_agent = tmp_path / "agent"
    fake_agent.write_text("#!/usr/bin/env bash\necho fake-agent\n", encoding="utf-8")
    fake_agent.chmod(0o755)
    config_path.write_text(
        json.dumps(
            {
                "state_dir": str(state_dir),
                "stream_command": [str(fake_agent)],
                "acp_command": [str(fake_agent), "acp"],
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))

    result = cursor_harness_config({"action": "validate", "include_sdk_status": False, "as_dict": True})

    assert isinstance(result, dict)
    assert result["success"] is True
    assert result["summary"]["errors"] == 0
