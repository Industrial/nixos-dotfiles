from __future__ import annotations

import json

from hermes_cursor_harness.config import HarnessConfig
from hermes_cursor_harness.proposal_queue import enqueue_cursor_proposal
from hermes_cursor_harness.store import HarnessStore, SessionRecord
from hermes_cursor_harness.cli import main


def test_cli_config_template_prints_valid_json(capsys) -> None:
    assert main(["config-template"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["transport"] == "auto"
    assert "hermes_cursor_status" in payload["trusted_readonly_mcp_tools"]
    assert payload["approval_bridge_command"] == ["hermes-cursor-harness", "approval-bridge"]


def test_cli_config_validate_reports_structured_checks(tmp_path, monkeypatch, capsys) -> None:
    project = tmp_path / "project"
    project.mkdir()
    fake_stream = tmp_path / "agent"
    fake_stream.write_text("#!/usr/bin/env bash\necho fake-agent\n", encoding="utf-8")
    fake_stream.chmod(0o755)
    config_path = tmp_path / "cursor_harness.json"
    config_path.write_text(
        json.dumps(
            {
                "state_dir": str(tmp_path / "state"),
                "projects": {"demo": str(project)},
                "stream_command": [str(fake_stream)],
                "acp_command": [str(fake_stream), "acp"],
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))

    assert main(["config", "validate", "--project", "demo", "--no-sdk-status"]) == 0
    payload = json.loads(capsys.readouterr().out)
    names = {item["name"] for item in payload["checks"]}
    assert payload["success"] is True
    assert "projects.demo" in names
    assert "commands.stream" in names


def test_cli_background_local_list(tmp_path, monkeypatch, capsys) -> None:
    config_path = tmp_path / "cursor_harness.json"
    config_path.write_text(json.dumps({"state_dir": str(tmp_path / "state")}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))

    assert main(["background", "local_list"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["success"] is True


def test_cli_background_launch_from_latest_requires_confirmation(tmp_path, monkeypatch, capsys) -> None:
    config_path = tmp_path / "cursor_harness.json"
    config_path.write_text(json.dumps({"state_dir": str(tmp_path / "state")}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))

    assert main(["background", "launch_from_latest", "--prompt", "Continue."]) == 1
    payload = json.loads(capsys.readouterr().out)
    assert payload["success"] is False
    assert "requires confirm_remote=true" in payload["error"]


def test_cli_background_key_status_reports_missing_key(tmp_path, monkeypatch, capsys) -> None:
    config_path = tmp_path / "cursor_harness.json"
    config_path.write_text(json.dumps({"state_dir": str(tmp_path / "state")}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))
    monkeypatch.delenv("CURSOR_BACKGROUND_API_KEY", raising=False)
    monkeypatch.delenv("CURSOR_API_KEY", raising=False)
    monkeypatch.setattr("hermes_cursor_harness.credentials.shutil.which", lambda name: None)

    assert main(["background-key", "status"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["success"] is True
    assert payload["available"] is False


def test_cli_api_key_alias_reports_missing_key(tmp_path, monkeypatch, capsys) -> None:
    config_path = tmp_path / "cursor_harness.json"
    config_path.write_text(json.dumps({"state_dir": str(tmp_path / "state")}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))
    monkeypatch.delenv("CURSOR_BACKGROUND_API_KEY", raising=False)
    monkeypatch.delenv("CURSOR_API_KEY", raising=False)
    monkeypatch.setattr("hermes_cursor_harness.credentials.shutil.which", lambda name: None)

    assert main(["api-key", "status"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["success"] is True
    assert payload["available"] is False


def test_cli_background_key_test_reports_missing_key(tmp_path, monkeypatch, capsys) -> None:
    config_path = tmp_path / "cursor_harness.json"
    config_path.write_text(json.dumps({"state_dir": str(tmp_path / "state")}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))
    monkeypatch.delenv("CURSOR_BACKGROUND_API_KEY", raising=False)
    monkeypatch.delenv("CURSOR_API_KEY", raising=False)
    monkeypatch.setattr("hermes_cursor_harness.credentials.shutil.which", lambda name: None)

    assert main(["background-key", "test"]) == 1
    payload = json.loads(capsys.readouterr().out)
    assert payload["success"] is False
    assert "not configured" in payload["error"]


def test_cli_approvals_list(tmp_path, monkeypatch, capsys) -> None:
    config_path = tmp_path / "cursor_harness.json"
    config_path.write_text(json.dumps({"state_dir": str(tmp_path / "state")}), encoding="utf-8")
    monkeypatch.setenv("HERMES_CURSOR_HARNESS_CONFIG", str(config_path))

    assert main(["approvals", "list"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["success"] is True


def test_cli_proposals_list_and_accept(tmp_path, monkeypatch, capsys) -> None:
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
    record.cursor_session_id = "cur_cli"
    store.upsert(record)
    item = enqueue_cursor_proposal(
        HarnessConfig(state_dir=state_dir),
        {
            "title": "Capture Cursor finding",
            "body": "Cursor found a follow-up worth tracking.",
            "harness_session_id": record.harness_session_id,
            "cursor_session_id": record.cursor_session_id,
        },
    )

    assert main(["proposals", "list"]) == 0
    listed = json.loads(capsys.readouterr().out)
    assert listed["proposals"][0]["id"] == item["id"]

    assert main(["inbox"]) == 0
    inbox = json.loads(capsys.readouterr().out)
    assert inbox["summary"]["pending"] == 1
    assert inbox["items"][0]["proposal"]["id"] == item["id"]

    assert main(["inbox", "--format", "text"]) == 0
    text_inbox = capsys.readouterr().out
    assert "Cursor Proposal Inbox" in text_inbox
    assert item["id"] in text_inbox

    assert main(["proposals", "inbox", "--format", "text"]) == 0
    text_proposals_inbox = capsys.readouterr().out
    assert "Actions: get, accept, reject, done, archive, cancel" in text_proposals_inbox

    assert main(["proposals", "accept", item["id"], "--reason", "Looks useful."]) == 0
    accepted = json.loads(capsys.readouterr().out)
    assert accepted["proposal"]["status"] == "accepted"
    assert accepted["proposal"]["resolution"]["reason"] == "Looks useful."
    assert accepted["resolution_event"]["type"] == "cursor_companion_proposal_resolution"
    assert store.read_events(record.harness_session_id)[0]["source"] == "hermes_cli"
