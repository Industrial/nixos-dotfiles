from __future__ import annotations

import json
from pathlib import Path

from hermes_cursor_harness.store import HarnessStore, SessionRecord


def test_session_name_tag_archive_export_and_prune(tmp_path: Path) -> None:
    store = HarnessStore(tmp_path / "state")
    record = SessionRecord.new(project_path=str(tmp_path), transport="stream", mode="plan", model=None, permission_policy="plan")
    store.upsert(record)
    store.append_event(record.harness_session_id, {"type": "message_delta", "text": "hi"})

    updated = store.update_session(record.harness_session_id, name="Smoke Session", tags=[" smoke ", ""], archived=True)
    assert updated.name == "Smoke Session"
    assert updated.tags == ["smoke"]
    assert updated.archived is True

    exported = store.export_session(record.harness_session_id)
    payload = json.loads(Path(exported["path"]).read_text(encoding="utf-8"))
    assert payload["session"]["name"] == "Smoke Session"
    assert payload["events"][0]["text"] == "hi"

    pruned = store.prune_sessions(keep_last=0, dry_run=True)
    assert record.harness_session_id in pruned["removed"]


def test_session_records_ignore_unknown_future_fields(tmp_path: Path) -> None:
    store = HarnessStore(tmp_path / "state")
    record = SessionRecord.new(project_path=str(tmp_path), transport="stream", mode="plan", model=None, permission_policy="plan")
    store.upsert(record)
    state = json.loads(store.state_path.read_text(encoding="utf-8"))
    state["sessions"][record.harness_session_id]["future_field"] = "ok"
    store.state_path.write_text(json.dumps(state), encoding="utf-8")

    loaded = store.get(record.harness_session_id)

    assert loaded is not None
    assert loaded.harness_session_id == record.harness_session_id
