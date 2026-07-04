from __future__ import annotations

from pathlib import Path

import pytest

from hermes_cursor_harness.config import HarnessConfig
from hermes_cursor_harness.proposal_queue import (
    enqueue_cursor_proposal,
    get_cursor_proposal,
    list_cursor_proposals,
    proposal_inbox,
    proposal_inbox_text,
    resolve_cursor_proposal,
)


def test_proposal_queue_lists_pending_and_resolves(tmp_path: Path) -> None:
    cfg = HarnessConfig(state_dir=tmp_path / "state")

    proposal = enqueue_cursor_proposal(
        cfg,
        {
            "kind": "memory_update",
            "title": "Remember test command",
            "body": "Cursor proposes storing pytest -q as the project test command.",
            "priority": "high",
            "harness_session_id": "hch_test",
        },
    )
    listed = list_cursor_proposals(cfg)
    resolved = resolve_cursor_proposal(cfg, proposal["id"], status="accepted", reason="Looks useful")

    assert listed[0]["id"] == proposal["id"]
    assert get_cursor_proposal(cfg, proposal["id"]) is not None
    assert resolved["status"] == "accepted"
    assert resolved["resolution"]["reason"] == "Looks useful"
    assert list_cursor_proposals(cfg) == []
    assert list_cursor_proposals(cfg, include_resolved=True)[0]["id"] == proposal["id"]


def test_proposal_queue_rejects_invalid_ids_and_reresolution(tmp_path: Path) -> None:
    cfg = HarnessConfig(state_dir=tmp_path / "state")
    proposal = enqueue_cursor_proposal(cfg, {"title": "One-way decision", "body": "Resolve only once."})

    resolve_cursor_proposal(cfg, proposal["id"], status="accepted")

    with pytest.raises(ValueError, match="already resolved"):
        resolve_cursor_proposal(cfg, proposal["id"], status="rejected")

    with pytest.raises(ValueError, match="proposal_id may only contain"):
        get_cursor_proposal(cfg, "../bad")


def test_proposal_queue_requires_title_and_body(tmp_path: Path) -> None:
    cfg = HarnessConfig(state_dir=tmp_path / "state")

    with pytest.raises(ValueError, match="title is required"):
        enqueue_cursor_proposal(cfg, {"body": "missing title"})

    with pytest.raises(ValueError, match="body is required"):
        enqueue_cursor_proposal(cfg, {"title": "Missing body"})


def test_proposal_inbox_text_is_human_reviewable(tmp_path: Path) -> None:
    cfg = HarnessConfig(state_dir=tmp_path / "state")
    proposal = enqueue_cursor_proposal(
        cfg,
        {
            "kind": "task_update",
            "title": "Track Cursor follow-up",
            "body": "Cursor found a useful follow-up.",
            "priority": "urgent",
            "project": str(tmp_path),
        },
    )

    rendered = proposal_inbox_text(proposal_inbox(cfg))

    assert "Cursor Proposal Inbox" in rendered
    assert "pending=1" in rendered
    assert "[urgent]" in rendered
    assert proposal["id"] in rendered
    assert "Actions: get, accept, reject, done, archive, cancel" in rendered
