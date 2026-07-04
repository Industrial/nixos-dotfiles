#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PYTHON="${PYTHON:-python3}"
SKIP_BUILD=0
REAL_PROJECT=""
INCLUDE_SDK=0
BACKGROUND_API=0
DISABLE_SDK_SANDBOX=0

usage() {
  cat <<'USAGE'
Usage: scripts/release_check.sh [options]

Options:
  --skip-build                 Skip python -m build and twine check.
  --real-project PATH          Run real Cursor smoke against a project path or alias.
  --include-sdk                Include SDK-specific real smoke/catalog checks.
  --background-api             Require and test a real Cursor API key.
  --disable-sdk-sandbox        Run local Cursor SDK smoke without SDK sandboxing.
  -h, --help                   Show this help.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --real-project)
      REAL_PROJECT="${2:-}"
      if [ -z "$REAL_PROJECT" ]; then
        echo "--real-project requires a value" >&2
        exit 2
      fi
      shift 2
      ;;
    --include-sdk)
      INCLUDE_SDK=1
      shift
      ;;
    --background-api)
      BACKGROUND_API=1
      shift
      ;;
    --disable-sdk-sandbox)
      DISABLE_SDK_SANDBOX=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

export PYTHONPATH="${PYTHONPATH:-.}"
FAKE_ACP_COMMAND="$PYTHON tests/fakes/fake_cursor_acp.py"
FAKE_STREAM_COMMAND="$PYTHON tests/fakes/fake_cursor_stream.py"
if [ "$DISABLE_SDK_SANDBOX" -eq 1 ]; then
  export HERMES_CURSOR_HARNESS_SDK_SANDBOX_ENABLED=false
fi

section() {
  printf '\n== %s ==\n' "$1"
}

section "Compile"
"$PYTHON" -m py_compile hermes_cursor_harness/*.py tests/fakes/*.py

section "Cursor SDK bridge syntax"
node --check hermes_cursor_harness/sdk_bridge.mjs

section "Unit tests"
"$PYTHON" -m pytest -q

section "Config validation"
env \
  HERMES_CURSOR_HARNESS_ACP_COMMAND="${HERMES_CURSOR_HARNESS_ACP_COMMAND:-$FAKE_ACP_COMMAND}" \
  HERMES_CURSOR_HARNESS_STREAM_COMMAND="${HERMES_CURSOR_HARNESS_STREAM_COMMAND:-$FAKE_STREAM_COMMAND}" \
  "$PYTHON" -m hermes_cursor_harness.cli config validate --no-sdk-status

section "Quick smoke"
env \
  HERMES_CURSOR_HARNESS_ACP_COMMAND="${HERMES_CURSOR_HARNESS_ACP_COMMAND:-$FAKE_ACP_COMMAND}" \
  HERMES_CURSOR_HARNESS_STREAM_COMMAND="${HERMES_CURSOR_HARNESS_STREAM_COMMAND:-$FAKE_STREAM_COMMAND}" \
  "$PYTHON" -m hermes_cursor_harness.cli smoke --level quick --json

section "Proposal inbox"
"$PYTHON" -m hermes_cursor_harness.cli inbox --format text --limit 5

if [ "$SKIP_BUILD" -eq 0 ]; then
  section "Package build"
  rm -rf dist build *.egg-info
  "$PYTHON" -m build
  "$PYTHON" -m twine check dist/*
fi

if [ -n "$REAL_PROJECT" ]; then
  section "Real Cursor smoke"
  real_args=(--level real --project "$REAL_PROJECT" --security-profile trusted-local --timeout-sec 180 --json)
  if [ "$INCLUDE_SDK" -eq 1 ]; then
    real_args+=(--include-sdk)
  fi
  "$PYTHON" -m hermes_cursor_harness.cli smoke "${real_args[@]}"
fi

if [ "$INCLUDE_SDK" -eq 1 ]; then
  section "Cursor SDK catalog"
  "$PYTHON" -m hermes_cursor_harness.cli sdk status
  "$PYTHON" -m hermes_cursor_harness.cli sdk models
fi

if [ "$BACKGROUND_API" -eq 1 ]; then
  section "Cursor API key"
  "$PYTHON" -m hermes_cursor_harness.cli api-key test
  "$PYTHON" -m hermes_cursor_harness.cli background list --limit 5
fi

section "Release check complete"
