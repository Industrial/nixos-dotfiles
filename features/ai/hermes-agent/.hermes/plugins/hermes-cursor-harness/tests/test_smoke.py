from __future__ import annotations

import sys
from pathlib import Path

from hermes_cursor_harness import smoke as smoke_mod
from hermes_cursor_harness.config import HarnessConfig
from hermes_cursor_harness.smoke import run_smoke_suite, summary_text
from hermes_cursor_harness.store import HarnessStore


def test_quick_smoke_reports_local_harness_shape(tmp_path: Path) -> None:
    fake_stream = Path(__file__).parent / "fakes" / "fake_cursor_stream.py"
    fake_acp = Path(__file__).parent / "fakes" / "fake_cursor_acp.py"
    cfg = HarnessConfig(
        transport="auto",
        acp_command=[sys.executable, str(fake_acp)],
        stream_command=[sys.executable, str(fake_stream)],
        state_dir=tmp_path / "state",
    )

    result = run_smoke_suite(cfg=cfg, store=HarnessStore(cfg.state_dir), level="quick")

    assert result["success"] is True
    names = {item["name"] for item in result["checks"]}
    assert "cursor.acp_command" in names
    assert "cursor.stream_command" in names
    assert "mcp.tools_shape" in names
    assert "mcp.bidirectional_backchannel" in names
    assert "store.sessions_readable" in names
    assert "Hermes Cursor Harness smoke: PASS" in summary_text(result)


def test_real_smoke_works_with_fake_cursor_transports(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setenv("FAKE_STREAM_ECHO_PROMPT", "1")
    monkeypatch.setenv("FAKE_ACP_ECHO_PROMPT", "1")
    monkeypatch.setenv("FAKE_NO_TOOL_CALL", "1")
    project = tmp_path / "project"
    project.mkdir()
    fake_stream = Path(__file__).parent / "fakes" / "fake_cursor_stream.py"
    fake_acp = Path(__file__).parent / "fakes" / "fake_cursor_acp.py"
    cfg = HarnessConfig(
        transport="auto",
        acp_command=[sys.executable, str(fake_acp)],
        stream_command=[sys.executable, str(fake_stream)],
        projects={"demo": str(project)},
        state_dir=tmp_path / "state",
    )

    result = run_smoke_suite(cfg=cfg, store=HarnessStore(cfg.state_dir), project="demo", level="real", timeout_sec=5)

    assert result["success"] is True
    names = {item["name"] for item in result["checks"]}
    assert "real.stream_plan" in names
    assert "real.stream_resume" in names
    assert "real.acp_plan" in names


def test_cursor_check_requires_sentinel_token(tmp_path: Path, monkeypatch) -> None:
    project = tmp_path / "project"
    project.mkdir()
    cfg = HarnessConfig(projects={"demo": str(project)}, state_dir=tmp_path / "state")
    store = HarnessStore(cfg.state_dir)

    def fake_run_turn(**kwargs):
        return {
            "success": True,
            "transport": kwargs["transport"],
            "harness_session_id": "hch_fake",
            "cursor_session_id": "cur_fake",
            "text": "nonempty response without the required token",
            "modified_files": [],
            "error": None,
        }

    monkeypatch.setattr(smoke_mod, "run_turn", fake_run_turn)
    checks: list[dict] = []

    smoke_mod._run_cursor_check(
        checks,
        cfg=cfg,
        store=store,
        project="demo",
        name="real.stream_plan",
        token="HCH_STREAM_SMOKE_OK",
        transport="stream",
        timeout_sec=5,
    )

    assert checks[-1]["status"] == "fail"
    assert checks[-1]["detail"]["token_seen"] is False
    assert checks[-1]["detail"]["text_present"] is True
