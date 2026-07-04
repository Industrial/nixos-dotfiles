#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${1:-$ROOT}"
TOKEN="${HERMES_CURSOR_HARNESS_DEMO_TOKEN:-HCH_USER_DEMO_OK}"
HARNESS_BIN="${HERMES_CURSOR_HARNESS_BIN:-hermes-cursor-harness}"

if [ -x "$ROOT/.venv/bin/python" ]; then
  PYTHON="${PYTHON:-$ROOT/.venv/bin/python}"
else
  PYTHON="${PYTHON:-python3}"
fi

export HERMES_CURSOR_HARNESS_SDK_SANDBOX_ENABLED="${HERMES_CURSOR_HARNESS_SDK_SANDBOX_ENABLED:-false}"
if [ -n "${HERMES_CURSOR_HARNESS_PLUGIN_DIR:-}" ]; then
  export PYTHONPATH="$HERMES_CURSOR_HARNESS_PLUGIN_DIR:${PYTHONPATH:-}"
fi

section() {
  printf '\n== %s ==\n' "$1"
}

section "Installed Harness Doctor"
"$HARNESS_BIN" doctor

section "Cursor API Key"
"$HARNESS_BIN" api-key test --timeout-sec 20

section "Cursor SDK"
"$HARNESS_BIN" sdk status
"$HARNESS_BIN" sdk models | "$PYTHON" -c '
import json, sys
data = json.load(sys.stdin)
models = data.get("result") or []
print(json.dumps({
    "success": data.get("success"),
    "model_count": len(models),
    "sample_models": [item.get("id") for item in models[:8]],
}, indent=2))
'

section "Background Agents API"
"$HARNESS_BIN" background list --limit 5

section "Direct Hermes Tool Run Through Cursor SDK"
"$PYTHON" - "$PROJECT" "$TOKEN" <<'PY'
import json
import sys

from hermes_cursor_harness.tools import cursor_harness_latest, cursor_harness_run

project = sys.argv[1]
token = sys.argv[2]
result = cursor_harness_run(
    {
        "as_dict": True,
        "project": project,
        "transport": "sdk",
        "mode": "plan",
        "new_session": True,
        "timeout_sec": 180,
        "prompt": (
            "Do not edit files. Reply with exactly one short paragraph that "
            f"includes {token} and says this answer came through the Hermes "
            "Cursor Harness using Cursor SDK."
        ),
    }
)
latest = cursor_harness_latest({"as_dict": True, "project": project})
print(
    json.dumps(
        {
            "success": result.get("success"),
            "transport": result.get("transport"),
            "harness_session_id": result.get("harness_session_id"),
            "cursor_session_id": result.get("cursor_session_id"),
            "sdk_run_id": result.get("sdk_run_id"),
            "token_seen": token in (result.get("text") or ""),
            "modified_files": result.get("modified_files"),
            "text": result.get("text"),
            "latest_transport": (latest.get("latest_session") or {}).get("transport"),
            "latest_status": (latest.get("latest_session") or {}).get("status"),
        },
        indent=2,
    )
)
PY
