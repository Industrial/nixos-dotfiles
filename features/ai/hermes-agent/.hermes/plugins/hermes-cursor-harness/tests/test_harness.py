from __future__ import annotations

from pathlib import Path

import pytest

from hermes_cursor_harness.config import HarnessConfig
from hermes_cursor_harness.harness import run_turn
from hermes_cursor_harness.store import HarnessStore, SessionRecord


def test_run_turn_rejects_empty_prompt(tmp_path: Path) -> None:
    project = tmp_path / "project"
    project.mkdir()
    cfg = HarnessConfig(transport="stream", projects={"demo": str(project)}, state_dir=tmp_path / "state")
    store = HarnessStore(cfg.state_dir)

    with pytest.raises(ValueError, match="prompt is required"):
        run_turn(cfg=cfg, store=store, project="demo", prompt="   ")


def test_run_turn_rejects_non_positive_timeout(tmp_path: Path) -> None:
    project = tmp_path / "project"
    project.mkdir()
    cfg = HarnessConfig(transport="stream", projects={"demo": str(project)}, state_dir=tmp_path / "state")
    store = HarnessStore(cfg.state_dir)

    with pytest.raises(ValueError, match="timeout_sec must be positive"):
        run_turn(cfg=cfg, store=store, project="demo", prompt="hi", timeout_sec=0)


def test_existing_session_cannot_be_retargeted_to_another_project(tmp_path: Path) -> None:
    project_a = tmp_path / "project-a"
    project_b = tmp_path / "project-b"
    project_a.mkdir()
    project_b.mkdir()
    cfg = HarnessConfig(
        transport="stream",
        projects={"a": str(project_a), "b": str(project_b)},
        state_dir=tmp_path / "state",
    )
    store = HarnessStore(cfg.state_dir)
    record = SessionRecord.new(
        project_path=str(project_a),
        transport="stream",
        mode="plan",
        model=None,
        permission_policy="plan",
    )
    store.upsert(record)

    with pytest.raises(ValueError, match="belongs to"):
        run_turn(
            cfg=cfg,
            store=store,
            project="b",
            prompt="hi",
            harness_session_id=record.harness_session_id,
        )


def test_hermes_session_id_reuses_matching_record(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    project = tmp_path / "project"
    project.mkdir()
    cfg = HarnessConfig(transport="stream", projects={"demo": str(project)}, state_dir=tmp_path / "state")
    store = HarnessStore(cfg.state_dir)
    record = SessionRecord.new(
        project_path=str(project),
        transport="stream",
        mode="plan",
        model=None,
        permission_policy="plan",
    )
    record.hermes_session_id = "hermes-session-1"
    store.upsert(record)

    def fake_stream_turn(**kwargs):
        return {"success": True, "harness_session_id": kwargs["record"].harness_session_id, "events": []}

    monkeypatch.setattr("hermes_cursor_harness.harness.run_stream_turn", fake_stream_turn)

    result = run_turn(
        cfg=cfg,
        store=store,
        project="demo",
        prompt="hi",
        hermes_session_id="hermes-session-1",
        transport="stream",
    )

    assert result["harness_session_id"] == record.harness_session_id


def test_hermes_session_id_does_not_reuse_other_hermes_session(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    project = tmp_path / "project"
    project.mkdir()
    cfg = HarnessConfig(transport="stream", projects={"demo": str(project)}, state_dir=tmp_path / "state")
    store = HarnessStore(cfg.state_dir)
    record = SessionRecord.new(
        project_path=str(project),
        transport="stream",
        mode="plan",
        model=None,
        permission_policy="plan",
    )
    record.hermes_session_id = "hermes-session-1"
    store.upsert(record)

    def fake_stream_turn(**kwargs):
        return {"success": True, "harness_session_id": kwargs["record"].harness_session_id, "events": []}

    monkeypatch.setattr("hermes_cursor_harness.harness.run_stream_turn", fake_stream_turn)

    result = run_turn(
        cfg=cfg,
        store=store,
        project="demo",
        prompt="hi",
        hermes_session_id="hermes-session-2",
        transport="stream",
    )

    assert result["harness_session_id"] != record.harness_session_id
    assert store.get(result["harness_session_id"]).hermes_session_id == "hermes-session-2"


def test_auto_transport_tries_sdk_first(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    project = tmp_path / "project"
    project.mkdir()
    cfg = HarnessConfig(transport="auto", projects={"demo": str(project)}, state_dir=tmp_path / "state")
    store = HarnessStore(cfg.state_dir)

    def fake_sdk_turn(**kwargs):
        return {"success": True, "transport": "sdk", "harness_session_id": kwargs["record"].harness_session_id, "events": []}

    def fail_acp_turn(**kwargs):
        raise AssertionError("ACP should not run when SDK succeeds")

    monkeypatch.setattr("hermes_cursor_harness.harness.run_sdk_turn", fake_sdk_turn)
    monkeypatch.setattr("hermes_cursor_harness.harness.run_acp_turn", fail_acp_turn)

    result = run_turn(cfg=cfg, store=store, project="demo", prompt="hi")

    assert result["transport"] == "sdk"


def test_auto_transport_falls_back_from_sdk_to_acp(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    project = tmp_path / "project"
    project.mkdir()
    cfg = HarnessConfig(transport="auto", projects={"demo": str(project)}, state_dir=tmp_path / "state")
    store = HarnessStore(cfg.state_dir)

    def fake_sdk_turn(**kwargs):
        raise RuntimeError("sdk unavailable")

    def fake_acp_turn(**kwargs):
        return {"success": True, "transport": "acp", "harness_session_id": kwargs["record"].harness_session_id, "events": []}

    monkeypatch.setattr("hermes_cursor_harness.harness.run_sdk_turn", fake_sdk_turn)
    monkeypatch.setattr("hermes_cursor_harness.harness.run_acp_turn", fake_acp_turn)

    result = run_turn(cfg=cfg, store=store, project="demo", prompt="hi")

    assert result["transport"] == "acp"
    assert "SDK failed" in result["fallback_reason"]
