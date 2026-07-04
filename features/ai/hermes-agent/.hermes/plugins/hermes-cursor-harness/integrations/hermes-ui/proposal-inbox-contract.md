# Hermes UI Proposal Inbox Contract

This contract is the UI-facing half of the Cursor-to-Hermes backchannel.
Cursor can append events and file proposals through the MCP companion, but
Hermes remains the authority that accepts, rejects, archives, or marks them
done.

## Data Source

Preferred Hermes tool:

```text
cursor_harness_proposal_inbox
```

Equivalent CLI:

```bash
hermes-cursor-harness inbox
hermes-cursor-harness inbox --format text
hermes-cursor-harness proposals inbox
```

The JSON shape is stable for UI use:

```json
{
  "success": true,
  "summary": {
    "total": 1,
    "pending": 1,
    "resolved": 0,
    "by_kind": {"task_update": 1},
    "by_priority": {"high": 1}
  },
  "items": [
    {
      "proposal": {
        "id": "hcp_...",
        "status": "pending",
        "kind": "task_update",
        "title": "Track Cursor follow-up",
        "body": "Cursor found a useful follow-up.",
        "priority": "high",
        "source": "cursor_mcp",
        "harness_session_id": "hch_...",
        "cursor_session_id": "cur_...",
        "project": "/absolute/path/to/repo",
        "payload": {},
        "created_at_ms": 1777580000000,
        "updated_at_ms": 1777580000000,
        "resolution": {}
      },
      "session": {},
      "linked_events": [],
      "actions": ["get", "accept", "reject", "done", "archive", "cancel"]
    }
  ],
  "next_actions": [
    "Review pending proposals with action=get or the proposal inbox.",
    "Resolve each pending proposal with accept, reject, done, archive, or cancel."
  ]
}
```

## UI Behavior

Show pending proposals first, then resolved proposals when the user enables a
history filter. Within pending items, sort by `priority` in this order:
`urgent`, `high`, `normal`, `low`, then by `updated_at_ms` descending.

Render these item fields:

- `proposal.title`
- `proposal.kind`
- `proposal.priority`
- `proposal.body`
- `proposal.project`
- `proposal.harness_session_id`
- `proposal.cursor_session_id`
- `linked_events`
- `actions`

Resolved items should show `proposal.status` and `proposal.resolution.reason`
when present.

## Actions

Use the `cursor_harness_proposals` tool:

```json
{"action": "accept", "proposal_id": "hcp_...", "reason": "Approved by user."}
```

Valid terminal actions:

- `accept`
- `reject`
- `done`
- `archive`
- `cancel`

A proposal can only be resolved once. When the proposal is linked to a harness
session, the decision is mirrored back as a
`cursor_companion_proposal_resolution` event so Cursor can observe the outcome
later.

## Authority Boundary

The UI must treat proposals as reviewable suggestions. A pending proposal must
not directly mutate Hermes memory, task state, tool policy, project policy, or
external services. The UI may offer a follow-up action after accepting a
proposal, but that follow-up should be another Hermes-owned operation with its
own permissions.

Cursor cannot spoof source authority through MCP. The harness pins MCP-created
proposals to `source: "cursor_mcp"` before writing them.
