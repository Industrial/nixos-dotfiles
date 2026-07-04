from __future__ import annotations

import json
import sys
from pathlib import Path

from hermes_cursor_harness.approval import select_permission_option


OPTIONS = [
    {"optionId": "allow-once", "kind": "allow_once"},
    {"optionId": "reject-once", "kind": "reject_once"},
]


def test_trusted_mcp_permission_allows_once() -> None:
    selected, source, _ = select_permission_option(
        options=OPTIONS,
        policy="plan",
        params={"toolCall": {"title": "hermes-cursor-harness-hermes_cursor_status: hermes_cursor_status"}},
        trusted_readonly_mcp_tools={"hermes_cursor_status"},
    )

    assert selected == "allow-once"
    assert source == "trusted_mcp"


def test_approval_bridge_can_select_option(tmp_path: Path) -> None:
    bridge = tmp_path / "bridge.py"
    bridge.write_text(
        "import json, sys\n"
        "json.load(sys.stdin)\n"
        "print(json.dumps({'optionId': 'allow-once'}))\n",
        encoding="utf-8",
    )

    selected, source, _ = select_permission_option(
        options=OPTIONS,
        policy="plan",
        params={"toolCall": {"title": "edit"}},
        trusted_readonly_mcp_tools=set(),
        bridge_command=[sys.executable, str(bridge)],
    )

    assert selected == "allow-once"
    assert source == "bridge"


def test_policy_rejects_without_bridge_or_trust() -> None:
    selected, source, _ = select_permission_option(
        options=OPTIONS,
        policy="plan",
        params={"toolCall": {"title": "edit"}},
        trusted_readonly_mcp_tools=set(),
    )

    assert selected == "reject-once"
    assert source == "policy"
