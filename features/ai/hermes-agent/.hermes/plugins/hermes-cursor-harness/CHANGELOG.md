# Changelog

## 0.1.1 - 2026-05-01

- Scoped Cursor and approval-bridge subprocess environments so unrelated
  provider, Gateway, GitHub, and shell tokens are not inherited by child
  runtimes.
- Added regression coverage for child environment filtering.

## 0.1.0 - 2026-05-01

Initial public alpha of Hermes Cursor Harness.

- Added Hermes plugin tools for Cursor-powered coding turns, sessions, events, models, diagnostics, security profiles, provider-route validation, compatibility records, Background Agents, approval queues, and Cursor-to-Hermes proposal queues.
- Added Cursor SDK-first execution through `@cursor/sdk`, with ACP and Cursor Agent `stream-json` fallback.
- Added SDK install/status/catalog helpers and local/cloud SDK runtime configuration.
- Added durable Hermes-side session and event storage under `~/.hermes/cursor_harness`.
- Added Cursor-side MCP/rules/skills companion installation for Hermes context backchannel use, including read-only context lookups, session event mirroring, and reviewable Cursor-to-Hermes proposals.
- Hardened Cursor-to-Hermes proposal handling with strict proposal IDs, one-time resolution, MCP source pinning, and config/profile rejection for writeback tools in trusted read-only MCP lists.
- Added permanent bidirectional smoke coverage, structured config validation, a Hermes UI-friendly proposal inbox, richer compatibility matrix records, and a private Cursor SDK compatibility workflow.
- Added terminal proposal inbox rendering, a Hermes UI proposal contract, a Hermes core upstreaming checklist, a demo project, and a reusable `scripts/release_check.sh` release gate.
- Added official Hermes pip-plugin entry point metadata, packaged plugin skill data, and a launch checklist with upstream PR and X post drafts.
- Added `HERMES_CURSOR_HARNESS_SDK_SANDBOX_ENABLED` and a release-check flag for environments where Cursor SDK local sandboxing is unsupported.
- Added security profiles for read-only, repo-edit, trusted-local, and Background Agent workflows.
- Added file-backed approval bridge support for Hermes UI integrations.
- Added macOS Keychain-backed Cursor API key management and `/v0/me` validation for SDK/Background Agent use.
- Added redacted diagnostics bundle generation and compatibility matrix recording.
- Added upstreaming bundle support for native Hermes `cursor/*` provider routing.
- Added fake Cursor SDK/ACP/stream test fixtures and local smoke suites.
- Hardened command discovery outside shell PATH, installed CLI/MCP wrappers,
  approval bridge defaults, and remote Background Agent mutation confirmations.
