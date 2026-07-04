from __future__ import annotations

import json
import zipfile
from pathlib import Path

from hermes_cursor_harness.config import HarnessConfig
from hermes_cursor_harness.diagnostics import create_diagnostic_bundle
from hermes_cursor_harness.proposal_queue import enqueue_cursor_proposal
from hermes_cursor_harness.store import HarnessStore, SessionRecord


def test_diagnostic_bundle_writes_redacted_zip(tmp_path: Path, monkeypatch) -> None:
    monkeypatch.setenv("CURSOR_API_KEY", "secret")
    cfg = HarnessConfig(stream_command=["missing-cursor"], acp_command=["missing-cursor", "acp"], state_dir=tmp_path / "state")
    store = HarnessStore(cfg.state_dir)
    record = SessionRecord.new(project_path=str(tmp_path), transport="stream", mode="plan", model=None, permission_policy="plan")
    record.last_result = "done"
    store.upsert(record)
    store.append_event(record.harness_session_id, {"type": "tool", "api_key": "secret"})
    store.record_background_agent({"id": "bg_1", "result": {"webhook_secret": "secret"}})
    enqueue_cursor_proposal(cfg, {"title": "Share token note", "body": "No secret here.", "payload": {"api_token": "secret"}})

    result = create_diagnostic_bundle(cfg=cfg, store=store, output_dir=tmp_path / "diag")

    assert result["success"] is True
    with zipfile.ZipFile(result["path"]) as zf:
        assert "summary.json" in zf.namelist()
        env = zf.read("environment.json").decode("utf-8")
        sessions = zf.read("sessions.json").decode("utf-8")
        events = zf.read(f"events/{record.harness_session_id}.json").decode("utf-8")
        summary = json.loads(zf.read("summary.json").decode("utf-8"))
    assert "secret" not in env
    assert "secret" not in sessions
    assert "secret" not in events
    assert summary["background_agents"][0]["result"]["webhook_secret"] == "[redacted]"
    assert summary["proposals"][0]["payload"]["api_token"] == "[redacted]"
    assert "[redacted]" in env
