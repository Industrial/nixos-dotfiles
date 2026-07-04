from __future__ import annotations

import sys
from pathlib import Path

import pytest

from hermes_cursor_harness.config import HarnessConfig
from hermes_cursor_harness.harness import run_turn
from hermes_cursor_harness.store import HarnessStore


def test_acp_turn_uses_session_prompt_and_records_events(tmp_path: Path) -> None:
    project = tmp_path / "project"
    project.mkdir()
    fake = Path(__file__).parent / "fakes" / "fake_cursor_acp.py"
    cfg = HarnessConfig(
        transport="acp",
        acp_command=[sys.executable, str(fake)],
        projects={"demo": str(project)},
        state_dir=tmp_path / "state",
    )
    store = HarnessStore(cfg.state_dir)

    result = run_turn(cfg=cfg, store=store, project="demo", prompt="say hi", mode="edit")

    assert result["success"] is True
    assert result["transport"] == "acp"
    assert result["cursor_session_id"] == "cur_acp_test"
    assert result["text"] == "acp hello"
    events = store.read_events(result["harness_session_id"], limit=-1)
    assert any(item["type"] == "session_started" for item in events)
    assert any(item["type"] == "tool_call" and item.get("tool_name") == "edit" for item in events)


def test_acp_turn_invokes_event_callback(tmp_path: Path) -> None:
    project = tmp_path / "project"
    project.mkdir()
    fake = Path(__file__).parent / "fakes" / "fake_cursor_acp.py"
    cfg = HarnessConfig(
        transport="acp",
        acp_command=[sys.executable, str(fake)],
        projects={"demo": str(project)},
        state_dir=tmp_path / "state",
    )
    store = HarnessStore(cfg.state_dir)
    seen: list[dict] = []

    result = run_turn(
        cfg=cfg,
        store=store,
        project="demo",
        prompt="say hi",
        mode="edit",
        event_callback=seen.append,
    )

    assert result["success"] is True
    assert any(item["type"] == "message_delta" and item.get("text") == "acp hello" for item in seen)


def test_auto_transport_falls_back_to_stream(tmp_path: Path) -> None:
    project = tmp_path / "project"
    project.mkdir()
    fake_stream = Path(__file__).parent / "fakes" / "fake_cursor_stream.py"
    cfg = HarnessConfig(
        transport="auto",
        acp_command=[sys.executable, str(tmp_path / "missing_acp.py")],
        stream_command=[sys.executable, str(fake_stream)],
        projects={"demo": str(project)},
        state_dir=tmp_path / "state",
        sdk_auto_install=False,
    )
    store = HarnessStore(cfg.state_dir)

    result = run_turn(cfg=cfg, store=store, project="demo", prompt="say hi", mode="plan", timeout_sec=2)

    assert result["success"] is True
    assert result["transport"] == "stream"
    assert "fallback_reason" in result


def test_acp_permission_response_uses_selected_outcome(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("FAKE_ACP_PERMISSION", "1")
    project = tmp_path / "project"
    project.mkdir()
    fake = Path(__file__).parent / "fakes" / "fake_cursor_acp.py"
    cfg = HarnessConfig(
        transport="acp",
        acp_command=[sys.executable, str(fake)],
        projects={"demo": str(project)},
        state_dir=tmp_path / "state",
    )
    store = HarnessStore(cfg.state_dir)

    result = run_turn(cfg=cfg, store=store, project="demo", prompt="edit safely", mode="edit")

    assert result["success"] is True
    events = store.read_events(result["harness_session_id"], limit=-1)
    permission_events = [item for item in events if item["type"] == "permission_request"]
    assert permission_events
    assert permission_events[-1]["selected_option"] == "allow_once_id"


def test_acp_plan_mode_allows_trusted_readonly_hermes_mcp(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("FAKE_ACP_HERMES_MCP_PERMISSION", "1")
    project = tmp_path / "project"
    project.mkdir()
    fake = Path(__file__).parent / "fakes" / "fake_cursor_acp.py"
    cfg = HarnessConfig(
        transport="acp",
        acp_command=[sys.executable, str(fake)],
        projects={"demo": str(project)},
        state_dir=tmp_path / "state",
    )
    store = HarnessStore(cfg.state_dir)

    result = run_turn(cfg=cfg, store=store, project="demo", prompt="read hermes context", mode="plan")

    assert result["success"] is True
    events = store.read_events(result["harness_session_id"], limit=-1)
    permission_events = [item for item in events if item["type"] == "permission_request"]
    assert permission_events
    assert permission_events[-1]["selected_option"] == "allow-once"


def test_acp_plan_mode_rejects_untrusted_hermes_mcp_when_not_whitelisted(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("FAKE_ACP_HERMES_MCP_PERMISSION", "1")
    project = tmp_path / "project"
    project.mkdir()
    fake = Path(__file__).parent / "fakes" / "fake_cursor_acp.py"
    cfg = HarnessConfig(
        transport="acp",
        acp_command=[sys.executable, str(fake)],
        projects={"demo": str(project)},
        state_dir=tmp_path / "state",
        trusted_readonly_mcp_tools=[],
    )
    store = HarnessStore(cfg.state_dir)

    with pytest.raises(Exception, match="bad mcp permission outcome"):
        run_turn(cfg=cfg, store=store, project="demo", prompt="read hermes context", mode="plan")

    records = store.list_sessions()
    assert records[-1]["status"] == "failed"


def test_acp_unknown_client_request_gets_method_not_found(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("FAKE_ACP_UNSUPPORTED", "1")
    project = tmp_path / "project"
    project.mkdir()
    fake = Path(__file__).parent / "fakes" / "fake_cursor_acp.py"
    cfg = HarnessConfig(
        transport="acp",
        acp_command=[sys.executable, str(fake)],
        projects={"demo": str(project)},
        state_dir=tmp_path / "state",
    )
    store = HarnessStore(cfg.state_dir)

    result = run_turn(cfg=cfg, store=store, project="demo", prompt="say hi", mode="plan")

    assert result["success"] is True
    events = store.read_events(result["harness_session_id"], limit=-1)
    assert any(item["type"] == "unsupported_acp_request" and item.get("method") == "terminal/create" for item in events)


def test_acp_create_plan_request_is_captured_as_output(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("FAKE_ACP_CREATE_PLAN", "1")
    project = tmp_path / "project"
    project.mkdir()
    fake = Path(__file__).parent / "fakes" / "fake_cursor_acp.py"
    cfg = HarnessConfig(
        transport="acp",
        acp_command=[sys.executable, str(fake)],
        projects={"demo": str(project)},
        state_dir=tmp_path / "state",
    )
    store = HarnessStore(cfg.state_dir)

    result = run_turn(
        cfg=cfg,
        store=store,
        project="demo",
        prompt="Do not edit files. Include HCH_ACP_SMOKE_OK in the final answer.",
        mode="plan",
    )

    assert result["success"] is True
    assert "HCH_ACP_SMOKE_OK" in result["text"]
    events = store.read_events(result["harness_session_id"], limit=-1)
    assert any(item["type"] == "plan" and "HCH_ACP_SMOKE_OK" in item.get("text", "") for item in events)
    assert not any(item["type"] == "unsupported_acp_request" and item.get("method") == "cursor/create_plan" for item in events)
