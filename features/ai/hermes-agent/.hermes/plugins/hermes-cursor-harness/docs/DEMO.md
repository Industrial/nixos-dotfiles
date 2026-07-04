# Demo Runbook

This runbook is the public proof path for a fresh Hermes Cursor Harness install.

## Setup

```bash
./install.sh
hermes-cursor-harness doctor
hermes-cursor-harness config validate
hermes-cursor-harness sdk install
hermes-cursor-harness sdk status
hermes-cursor-harness smoke --level quick --json
```

`sdk status` should report the installed `@cursor/sdk` version. SDK account
catalog commands such as `sdk models` require a real Cursor API key. Use
`hermes-cursor-harness api-key set` to store one in Keychain when available.

For a harmless local repo, use `examples/demo_project/` and merge its
`cursor_harness.demo.json` project alias into your config.

## Real Cursor Transport Demo

Run this from any repository Cursor is allowed to inspect:

```bash
hermes-cursor-harness smoke \
  --level real \
  --project /absolute/path/to/repo \
  --security-profile trusted-local \
  --timeout-sec 180 \
  --json
```

Expected checks:

- `mcp.bidirectional_backchannel` passes in every quick/real/full smoke.
- Optional: `real.sdk_plan` passes when you add `--include-sdk` and the Cursor
  SDK auth path is configured.
- `real.models` passes.
- `real.stream_plan` passes.
- `real.stream_resume` passes with the same Cursor session ID.
- `real.acp_plan` passes.

For an SDK-first transport demo:

```bash
hermes-cursor-harness smoke \
  --level real \
  --project /absolute/path/to/repo \
  --include-sdk \
  --timeout-sec 180 \
  --json
```

## Approval Bridge Demo

```bash
scripts/demo_approval_bridge.sh
```

Expected output includes:

```json
{"bridge":{"optionId":"allow-once"},"bridge_rc":0,"decide_rc":0}
```

## Cursor-To-Hermes Proposal Demo

Cursor can write back to Hermes through the MCP server without gaining Hermes
authority. From Hermes, review that queue with:

```bash
hermes-cursor-harness proposals list
hermes-cursor-harness inbox --format text
```

After Cursor calls `hermes_cursor_propose`, accept or reject the handoff:

```bash
hermes-cursor-harness proposals accept hcp_... --reason "Approved by user."
hermes-cursor-harness proposals reject hcp_... --reason "Out of scope."
```

The proposal remains a queue item until Hermes resolves it; it does not mutate
memory, policy, tools, or task state on its own. If the proposal is tied to a
harness session, Hermes' accept/reject/done/archive decision is mirrored back
into that session's event stream for Cursor to read later.

## Compatibility Matrix Demo

Record the current machine, SDK, Cursor CLI, MCP, and smoke capabilities:

```bash
hermes-cursor-harness compatibility run \
  --level real \
  --project /absolute/path/to/repo \
  --timeout-sec 180
```

With SDK auth configured, add `--include-sdk`. Records are written to
`~/.hermes/cursor_harness/compatibility_matrix.json`.

## Provider Route Demo

For a patched Hermes checkout:

```bash
hermes-cursor-harness provider-route bundle \
  --hermes-root /path/to/hermes \
  --output-dir /tmp/hermes-cursor-provider-route
```

Expected files:

- `provider-route-manifest.json`
- `README.md`
- `cursor-provider-route.patch`

## Background Agent Demo

Without an API key, local metadata still works:

```bash
hermes-cursor-harness background-key status
hermes-cursor-harness background local_list
```

To store and test a Cursor Dashboard API key:

```bash
hermes-cursor-harness background-key set
hermes-cursor-harness background-key test
```

Then run a live API read:

```bash
hermes-cursor-harness background list --limit 5
```
