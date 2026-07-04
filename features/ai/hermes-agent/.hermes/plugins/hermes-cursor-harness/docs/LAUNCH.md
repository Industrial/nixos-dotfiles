# Launch Plan

This is the publish-and-upstream checklist for Hermes Cursor Harness.

## Live Test Ladder

Run these before every public release:

```bash
scripts/release_check.sh
```

This proves the public, credential-free path: compile, unit tests, config
validation, quick smoke, bidirectional MCP backchannel, proposal inbox rendering,
build, and `twine check`.

Run the real local Cursor transport gate:

```bash
scripts/release_check.sh \
  --real-project /absolute/path/to/repo
```

This proves local Cursor model listing, stream-json plan/resume, ACP plan,
Cursor calling Hermes MCP, and concurrent session isolation.

Run the SDK-auth gate when a real Cursor API key is configured:

```bash
hermes-cursor-harness api-key set
scripts/release_check.sh \
  --real-project /absolute/path/to/repo \
  --include-sdk \
  --background-api
```

If local Cursor SDK sandboxing is unsupported on the test machine, add:

```bash
--disable-sdk-sandbox
```

This proves official Cursor SDK catalog/auth coverage and live Background
Agents API access.

Run the Hermes-side gate:

```bash
python -m pip install dist/hermes_cursor_harness-0.1.1-py3-none-any.whl

HERMES_HOME="$(mktemp -d)" python - <<'PY'
from pathlib import Path
from hermes_cli.plugins import PluginManager
home = Path(__import__("os").environ["HERMES_HOME"])
home.mkdir(parents=True, exist_ok=True)
(home / "config.yaml").write_text("plugins:\n  enabled:\n    - hermes-cursor-harness\n")
pm = PluginManager()
pm.discover_and_load(force=True)
plugin = pm._plugins.get("hermes-cursor-harness")
assert plugin and plugin.enabled and "cursor_harness_run" in plugin.tools_registered
assert "hermes-cursor-harness:cursor-harness" in pm._plugin_skills
print("Hermes plugin discovery passed")
PY
```

For a patched Hermes checkout:

```bash
hermes-cursor-harness provider-route status --hermes-root /path/to/hermes-agent
python -m pytest -q -o addopts='' tests/test_cursor_harness_provider.py
```

## Publish

1. Create the public GitHub repository.
2. Push this package as `hermes-cursor-harness`.
3. Add GitHub Actions secrets:
   - `CURSOR_API_KEY` for the private compatibility lane.
   - `CURSOR_AGENT_INSTALL_COMMAND` only if the runner needs a Cursor CLI install.
   - `PYPI_API_TOKEN` if publishing from CI.
4. Run public CI and private Cursor compatibility CI.
5. Tag `v0.1.1`.
6. Publish the package:

```bash
python -m twine upload dist/*
```

7. Attach:
   - `dist/hermes_cursor_harness-0.1.1.tar.gz`
   - `dist/hermes_cursor_harness-0.1.1-py3-none-any.whl`
   - `~/.hermes/cursor_harness/compatibility_matrix.json`
   - a provider-route bundle from `hermes-cursor-harness provider-route bundle`

## Upstream Into Hermes

Open two upstream artifacts against `NousResearch/hermes-agent`:

1. A PR for native provider routing:
   - Adds `cursor-harness` provider detection.
   - Routes `cursor/*` models to the installed package.
   - Keeps Hermes session/transcript/tool authority outside Cursor.
   - Adds provider-route tests.
2. A docs PR:
   - Adds Hermes Cursor Harness to plugin docs.
   - Explains user install, enablement, and `cursor/*` provider route.

Keep the package independent even if Hermes core accepts the provider route.
That lets users update the Cursor SDK bridge and compatibility handling without
waiting for a Hermes release.

## X Post Draft

I built Hermes Cursor Harness: a Hermes-native bridge that lets Hermes delegate
coding turns to Cursor while Hermes keeps the outer session, approvals, memory,
tools, and transcript.

It uses Cursor SDK first, then ACP / stream-json fallback, with live event
mirroring, resumable sessions, and a review-gated Cursor-to-Hermes proposal
inbox.

Why it matters: Hermes can keep being the long-running agent you talk to
everywhere, while Cursor owns the repo-local coding runtime it is great at.

Looking for Hermes + Cursor users to test it, file issues, and help upstream
native `cursor/*` routing into Hermes.

Repo: https://github.com/Cosmic-Construct/hermes-cursor-harness

## Short X Post Draft

I built a Hermes-native Cursor harness.

Hermes keeps session/memory/tools/approvals.
Cursor handles repo-local coding turns through SDK/ACP/stream-json.

Includes resumable sessions, live events, MCP backchannel, and a reviewable
Cursor-to-Hermes proposal inbox.

Testers wanted: https://github.com/Cosmic-Construct/hermes-cursor-harness
