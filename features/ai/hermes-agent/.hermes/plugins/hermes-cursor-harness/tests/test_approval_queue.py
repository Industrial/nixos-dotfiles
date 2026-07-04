from __future__ import annotations

import threading
import time
from pathlib import Path

from hermes_cursor_harness.approval_queue import (
    bridge_response_from_decision,
    decide_approval_request,
    enqueue_approval_request,
    list_approval_requests,
    wait_for_approval_decision,
)
from hermes_cursor_harness.config import HarnessConfig


OPTIONS = [
    {"optionId": "allow-once", "kind": "allow_once"},
    {"optionId": "reject-once", "kind": "reject_once"},
]


def test_approval_queue_waits_for_decision(tmp_path: Path) -> None:
    cfg = HarnessConfig(state_dir=tmp_path / "state")
    item = enqueue_approval_request(cfg, {"policy": "ask", "options": OPTIONS, "request": {"toolCall": {"title": "edit"}}})

    def decide_later() -> None:
        time.sleep(0.05)
        decide_approval_request(cfg, item["id"], option_id="allow-once")

    thread = threading.Thread(target=decide_later)
    thread.start()
    decision = wait_for_approval_decision(cfg, item["id"], timeout_sec=1)
    thread.join(timeout=1)

    assert decision["status"] == "approved"
    assert bridge_response_from_decision(decision) == {"optionId": "allow-once"}


def test_approval_queue_reject_outcome_selects_reject_option(tmp_path: Path) -> None:
    cfg = HarnessConfig(state_dir=tmp_path / "state")
    item = enqueue_approval_request(cfg, {"policy": "ask", "options": OPTIONS, "request": {}})

    decision = decide_approval_request(cfg, item["id"], outcome="reject")

    assert decision["status"] == "rejected"
    assert decision["selected_option"] == "reject-once"


def test_approval_queue_lists_pending_only_by_default(tmp_path: Path) -> None:
    cfg = HarnessConfig(state_dir=tmp_path / "state")
    item = enqueue_approval_request(cfg, {"policy": "ask", "options": OPTIONS, "request": {}})
    decide_approval_request(cfg, item["id"], outcome="reject")

    assert list_approval_requests(cfg) == []
    assert len(list_approval_requests(cfg, include_resolved=True)) == 1
