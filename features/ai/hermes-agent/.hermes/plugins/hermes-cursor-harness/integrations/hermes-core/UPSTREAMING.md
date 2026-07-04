# Hermes Core Upstreaming Checklist

This package can run as a stock Hermes plugin today. Native `cursor/*` model
selection requires a small Hermes core provider route because the public plugin
surface cannot replace the provider execution loop.

## Goal

The user should be able to select:

```yaml
model: cursor/default
provider: cursor-harness
```

Hermes keeps the outer runtime: session state, transcript, memory, approvals,
delivery surfaces, and permission policy. Cursor owns the inner coding-agent
run through the SDK, ACP, or stream-json fallback.

## Patch Requirements

- Add provider registration for `cursor-harness`.
- Route `cursor/*` model IDs to a Cursor harness provider.
- Call `hermes_cursor_harness.harness.run_turn(...)` from that provider.
- Pass through Hermes session identifiers so the harness can resume the right
  Cursor session.
- Stream normalized Cursor events into Hermes callbacks.
- Store `harness_session_id`, `cursor_session_id`, `transport`, and SDK run
  metadata in Hermes session metadata.
- Keep the implementation package external so users can upgrade the harness
  without waiting for a Hermes core release.

## Acceptance Tests

At minimum, upstream Hermes should add tests equivalent to:

- `model=cursor/default` selects the Cursor harness provider.
- A plan-mode turn delegates to `run_turn` and returns final text.
- Event callbacks receive normalized Cursor status/tool/output events.
- Follow-up turns reuse the stored `harness_session_id`.
- Provider route validation succeeds through:

```bash
hermes-cursor-harness provider-route status --hermes-root /path/to/hermes
```

## Bundle

Generate a review bundle:

```bash
hermes-cursor-harness provider-route bundle \
  --hermes-root /path/to/hermes \
  --output-dir /tmp/hermes-cursor-provider-route
```

The bundle includes a manifest, review README, and, when the supplied Hermes
root is a git checkout with local changes, `cursor-provider-route.patch`.

## Non-Goals

- Do not move Hermes memory or policy authority into Cursor.
- Do not make Cursor MCP writeback tools trusted read-only tools.
- Do not require Background Agents credentials for local Cursor harness runs.
- Do not couple this package to a private Hermes fork.
