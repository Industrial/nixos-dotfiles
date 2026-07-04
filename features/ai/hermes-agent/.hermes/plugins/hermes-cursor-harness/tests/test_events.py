from __future__ import annotations

from hermes_cursor_harness.events import modified_files_from_events


def test_modified_files_from_events_ignores_read_only_tools() -> None:
    events = [
        {
            "type": "tool_call",
            "tool_name": "read",
            "payload": {"args": {"path": "README.md"}},
        },
        {
            "type": "tool_call",
            "tool_name": "mcp",
            "payload": {"args": {"toolName": "hermes_cursor_status", "path": "status.json"}},
        },
    ]

    assert modified_files_from_events(events) == []


def test_modified_files_from_events_keeps_mutating_tools() -> None:
    events = [
        {
            "type": "tool_call",
            "tool_name": "edit_file",
            "payload": {"args": {"path": "README.md"}},
        },
        {
            "type": "tool_call",
            "tool_name": "write",
            "payload": {"path": "src/app.py"},
        },
    ]

    assert modified_files_from_events(events) == ["README.md", "src/app.py"]
