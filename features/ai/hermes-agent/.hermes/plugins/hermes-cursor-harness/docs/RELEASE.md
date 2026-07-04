# Release Guide

This project ships two things:

- A Python package with CLI/MCP entry points.
- A Hermes plugin bundle installed by `./install.sh`.

## Preflight

The public release gate is:

```bash
scripts/release_check.sh
```

It covers compile, Node syntax, unit tests, config validation, quick smoke,
proposal inbox rendering, package build, and `twine check`.

Equivalent manual steps:

```bash
python -m pip install -e ".[dev,release]"
python -m py_compile hermes_cursor_harness/*.py tests/fakes/*.py
node --check hermes_cursor_harness/sdk_bridge.mjs
python -m pytest -q
hermes-cursor-harness config validate --no-sdk-status
hermes-cursor-harness smoke --level quick --json
hermes-cursor-harness sdk install
hermes-cursor-harness sdk status
hermes-cursor-harness proposals list
hermes-cursor-harness inbox --format text
```

If Cursor is installed and logged in:

```bash
hermes-cursor-harness smoke --level real --project /absolute/path/to/repo --security-profile trusted-local --timeout-sec 180 --json
```

If Cursor SDK auth is configured:

```bash
hermes-cursor-harness api-key test
hermes-cursor-harness sdk models
hermes-cursor-harness smoke --level real --project /absolute/path/to/repo --include-sdk --timeout-sec 180 --json
hermes-cursor-harness compatibility run --level real --project /absolute/path/to/repo --include-sdk --timeout-sec 180
```

If a Cursor Background Agents key is configured:

```bash
hermes-cursor-harness background-key test
hermes-cursor-harness background list --limit 5
```

## Build

```bash
find . -maxdepth 1 -name '*.egg-info' -exec rm -rf {} +
rm -rf dist build
python -m build
python -m twine check dist/*
```

## Local Plugin Install

```bash
./install.sh
hermes-cursor-harness doctor
```

Enable `hermes-cursor-harness` in `~/.hermes/config.yaml` and add the
`cursor_harness` toolset to the Hermes surface that should expose it.

## Approval Bridge

For a Hermes UI approval modal, set:

```json
{
  "approval_bridge_command": ["hermes-cursor-harness", "approval-bridge"]
}
```

The bridge writes pending requests into `~/.hermes/cursor_harness/approvals`.
A Hermes UI can list and decide them through:

```bash
hermes-cursor-harness approvals list
hermes-cursor-harness approvals decide hca_... --option-id allow-once
```

or through the `cursor_harness_approvals` tool.

## Cursor-To-Hermes Proposals

The Cursor MCP companion can append session events and create reviewable
proposals. Hermes resolves those proposals through:

```bash
hermes-cursor-harness proposals list
hermes-cursor-harness proposals accept hcp_... --reason "Approved by user."
hermes-cursor-harness proposals reject hcp_... --reason "Out of scope."
```

or through the `cursor_harness_proposals` tool. Proposals are review-gated and
must not be treated as direct memory, policy, tool, or task mutations. Session
proposals mirror Hermes' resolution back into the harness event stream. A
proposal can only be resolved once.

Hermes UI surfaces should prefer `cursor_harness_proposal_inbox`, which returns
pending/resolved counts, proposal actions, linked harness sessions, and linked
proposal events.

The full UI contract and sample payload live in:

- `integrations/hermes-ui/proposal-inbox-contract.md`
- `integrations/hermes-ui/proposal-inbox-sample.json`

## Compatibility CI

Public CI uses fake Cursor transports for deterministic compile, unit, config,
and quick-smoke coverage. The private compatibility lane in
`.github/workflows/cursor-compatibility.yml` requires `CURSOR_API_KEY`, can use
`CURSOR_AGENT_INSTALL_COMMAND` to install a real Cursor CLI, and uploads the
generated compatibility matrix artifact.

## Upstream Provider Route

Generate the upstreaming checklist and manifest:

```bash
hermes-cursor-harness provider-route bundle --hermes-root /path/to/hermes --output-dir /tmp/hermes-cursor-provider-route
```

If maintaining a patched Hermes checkout, export a patch from that checkout and
place it under `integrations/hermes-core/` before tagging a release.

See `integrations/hermes-core/UPSTREAMING.md` for the provider-route acceptance
tests and non-goals.
