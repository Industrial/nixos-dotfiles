# Distribution Guide

This guide separates what maintainers can verify publicly from what requires
private Cursor credentials or upstream Hermes ownership.

## Public Release Gate

Run:

```bash
scripts/release_check.sh
```

The script performs:

- Python compile check.
- Cursor SDK bridge syntax check with Node.
- Unit tests.
- Config validation with SDK status disabled for deterministic public runs.
- Quick smoke with fake Cursor ACP and stream-json transports.
- Proposal inbox text rendering.
- Source distribution and wheel build.
- `twine check` on built artifacts.

Use `--skip-build` when another CI job is already building the package.

## Real Cursor Gate

On a machine with Cursor installed and logged in:

```bash
scripts/release_check.sh --real-project /absolute/path/to/repo
```

This adds a real Cursor smoke pass. Add `--include-sdk` when the official
Cursor SDK auth path is configured:

```bash
scripts/release_check.sh --real-project /absolute/path/to/repo --include-sdk
```

If the Cursor SDK reports that local sandboxing is unsupported in the current
environment, rerun with:

```bash
scripts/release_check.sh --real-project /absolute/path/to/repo --include-sdk --disable-sdk-sandbox
```

## Private API Gate

Cursor Dashboard API coverage requires a real key. Configure it through one of:

- `CURSOR_API_KEY`
- `CURSOR_BACKGROUND_API_KEY`
- `hermes-cursor-harness api-key set`

Then run:

```bash
scripts/release_check.sh --background-api
```

This validates the key and performs a live Background Agents list request.

## Publishing

1. Run the public release gate.
2. Run the real Cursor gate on macOS.
3. Run the private API gate when a Cursor Dashboard key is available.
4. Update `CHANGELOG.md`.
5. Tag the release.
6. Publish the Python package:

```bash
python -m twine upload dist/*
```

7. Attach the provider-route bundle and compatibility matrix to the release.

## External Completion Items

These cannot be completed from this standalone package alone:

- Publishing to PyPI requires package-owner credentials.
- Homebrew distribution requires a tap or formula repository.
- Native `cursor/*` model selection in stock Hermes requires an upstream
  Hermes provider-route patch.
- Live Background Agents verification requires a real Cursor Dashboard API key.
