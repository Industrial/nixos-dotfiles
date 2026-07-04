from __future__ import annotations

import sys
from pathlib import Path

import pytest

from hermes_cursor_harness.config import HarnessConfig
from hermes_cursor_harness.harness import run_turn
from hermes_cursor_harness.store import HarnessStore


def test_stream_json_turn_records_session_and_events(tmp_path: Path) -> None:
    project = tmp_path / "project"
    project.mkdir()
    fake = Path(__file__).parent / "fakes" / "fake_cursor_stream.py"
    cfg = HarnessConfig(
        transport="stream",
        stream_command=[sys.executable, str(fake)],
        projects={"demo": str(project)},
        state_dir=tmp_path / "state",
    )
    store = HarnessStore(cfg.state_dir)

    result = run_turn(cfg=cfg, store=store, project="demo", prompt="say hi", mode="edit")

    assert result["success"] is True
    assert result["transport"] == "stream"
    assert result["cursor_session_id"] == "cur_stream_test"
    assert result["text"] == "stream done"
    assert "README.md" in result["modified_files"]
    events = store.read_events(result["harness_session_id"], limit=-1)
    assert any(item["type"] == "message_delta" and item.get("text") == "stream hello" for item in events)


def test_stream_json_turn_invokes_event_callback(tmp_path: Path) -> None:
    project = tmp_path / "project"
    project.mkdir()
    fake = Path(__file__).parent / "fakes" / "fake_cursor_stream.py"
    cfg = HarnessConfig(
        transport="stream",
        stream_command=[sys.executable, str(fake)],
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
    assert any(item["type"] == "message_delta" and item.get("text") == "stream hello" for item in seen)


def test_stream_json_events_can_arrive_on_stderr(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("FAKE_STREAM_STDERR", "1")
    project = tmp_path / "project"
    project.mkdir()
    fake = Path(__file__).parent / "fakes" / "fake_cursor_stream.py"
    cfg = HarnessConfig(
        transport="stream",
        stream_command=[sys.executable, str(fake)],
        projects={"demo": str(project)},
        state_dir=tmp_path / "state",
    )
    store = HarnessStore(cfg.state_dir)

    result = run_turn(cfg=cfg, store=store, project="demo", prompt="say hi", mode="plan")

    assert result["success"] is True
    assert result["cursor_session_id"] == "cur_stream_test"
    assert result["text"] == "stream done"


def test_stream_reject_mode_maps_to_cursor_plan_mode(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("EXPECT_CURSOR_MODE", "plan")
    monkeypatch.setenv("EXPECT_CURSOR_TRUST", "1")
    project = tmp_path / "project"
    project.mkdir()
    fake = Path(__file__).parent / "fakes" / "fake_cursor_stream.py"
    cfg = HarnessConfig(
        transport="stream",
        stream_command=[sys.executable, str(fake)],
        projects={"demo": str(project)},
        state_dir=tmp_path / "state",
    )
    store = HarnessStore(cfg.state_dir)

    result = run_turn(cfg=cfg, store=store, project="demo", prompt="say hi", mode="reject")

    assert result["success"] is True


def test_stream_turn_times_out_when_cursor_produces_no_output(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("FAKE_STREAM_NO_OUTPUT", "1")
    monkeypatch.setenv("FAKE_STREAM_SLEEP", "5")
    project = tmp_path / "project"
    project.mkdir()
    fake = Path(__file__).parent / "fakes" / "fake_cursor_stream.py"
    cfg = HarnessConfig(
        transport="stream",
        stream_command=[sys.executable, str(fake)],
        projects={"demo": str(project)},
        state_dir=tmp_path / "state",
        no_output_timeout_sec=0.2,
    )
    store = HarnessStore(cfg.state_dir)

    result = run_turn(cfg=cfg, store=store, project="demo", prompt="say hi", mode="plan", timeout_sec=2)

    assert result["success"] is False
    assert result["error"] == "no output for 0.2s"
    assert store.get(result["harness_session_id"]).status == "failed"
