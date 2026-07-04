from __future__ import annotations

import sys
from pathlib import Path

from hermes_cursor_harness.config import HarnessConfig
from hermes_cursor_harness.harness import run_turn
from hermes_cursor_harness.sdk_runner import sdk_catalog_action, sdk_status
from hermes_cursor_harness.store import HarnessStore


def test_sdk_turn_records_session_events_and_result(tmp_path: Path) -> None:
    project = tmp_path / "project"
    project.mkdir()
    fake = Path(__file__).parent / "fakes" / "fake_cursor_sdk_bridge.py"
    cfg = HarnessConfig(
        transport="sdk",
        sdk_command=[sys.executable, str(fake)],
        projects={"demo": str(project)},
        state_dir=tmp_path / "state",
        default_model="composer-2",
    )
    store = HarnessStore(cfg.state_dir)

    result = run_turn(cfg=cfg, store=store, project="demo", prompt="say hi", mode="edit")

    assert result["success"] is True
    assert result["transport"] == "sdk"
    assert result["sdk_runtime"] == "local"
    assert result["cursor_session_id"] == "sdk_agent_test"
    assert result["sdk_run_id"] == "sdk_run_test"
    assert result["text"] == "sdk done"
    assert "README.md" in result["modified_files"]
    events = store.read_events(result["harness_session_id"], limit=-1)
    assert any(item["type"] == "message_delta" and item.get("text") == "sdk hello" for item in events)


def test_sdk_turn_invokes_event_callback(tmp_path: Path) -> None:
    project = tmp_path / "project"
    project.mkdir()
    fake = Path(__file__).parent / "fakes" / "fake_cursor_sdk_bridge.py"
    cfg = HarnessConfig(
        transport="sdk",
        sdk_command=[sys.executable, str(fake)],
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
        mode="plan",
        event_callback=seen.append,
    )

    assert result["success"] is True
    assert any(item["type"] == "session_started" and item.get("source") == "cursor_sdk" for item in seen)


def test_sdk_turn_falls_back_to_assistant_deltas_when_result_text_is_empty(
    tmp_path: Path,
    monkeypatch,
) -> None:
    project = tmp_path / "project"
    project.mkdir()
    fake = Path(__file__).parent / "fakes" / "fake_cursor_sdk_bridge.py"
    cfg = HarnessConfig(
        transport="sdk",
        sdk_command=[sys.executable, str(fake)],
        projects={"demo": str(project)},
        state_dir=tmp_path / "state",
    )
    store = HarnessStore(cfg.state_dir)
    monkeypatch.setenv("FAKE_SDK_EMPTY_RESULT", "1")

    result = run_turn(cfg=cfg, store=store, project="demo", prompt="say hi", mode="plan")

    assert result["success"] is True
    assert result["text"] == "sdk hello"


def test_sdk_status_and_catalog_actions_use_bridge(tmp_path: Path) -> None:
    fake = Path(__file__).parent / "fakes" / "fake_cursor_sdk_bridge.py"
    cfg = HarnessConfig(
        sdk_command=[sys.executable, str(fake)],
        state_dir=tmp_path / "state",
    )

    status = sdk_status(cfg)
    models = sdk_catalog_action(cfg, "models")

    assert status["success"] is True
    assert status["sdk_version"] == "fake"
    assert models["success"] is True
    assert models["result"][0]["id"] == "composer-2"
