#!/usr/bin/env bash
set -euo pipefail

TMPDIR="$(mktemp -d)"
STATE="$TMPDIR/state"
CONFIG="$TMPDIR/cursor_harness.json"
cat > "$CONFIG" <<JSON
{
  "state_dir": "$STATE",
  "approval_bridge_timeout_sec": 3
}
JSON

export HERMES_CURSOR_HARNESS_CONFIG="$CONFIG"

PAYLOAD='{"policy":"ask","options":[{"optionId":"allow-once","kind":"allow_once"},{"optionId":"reject-once","kind":"reject_once"}],"request":{"toolCall":{"title":"edit"}}}'

printf '%s' "$PAYLOAD" | hermes-cursor-harness approval-bridge --timeout-sec 3 > "$TMPDIR/bridge.out" &
BRIDGE_PID=$!

REQUEST_ID=""
for _ in $(seq 1 30); do
  if compgen -G "$STATE/approvals/*.json" > /dev/null; then
    REQUEST_ID="$(
      python3 - "$STATE" <<'PY'
import json
import sys
from pathlib import Path

state = Path(sys.argv[1])
path = next((state / "approvals").glob("*.json"))
print(json.loads(path.read_text(encoding="utf-8"))["id"])
PY
    )"
    break
  fi
  sleep 0.1
done

if [[ -z "$REQUEST_ID" ]]; then
  kill "$BRIDGE_PID" 2>/dev/null || true
  echo "approval request was not queued" >&2
  exit 1
fi

DECIDE_OUT="$(hermes-cursor-harness approvals decide "$REQUEST_ID" --option-id allow-once)"
wait "$BRIDGE_PID"
BRIDGE_OUT="$(cat "$TMPDIR/bridge.out")"

python3 - "$DECIDE_OUT" "$BRIDGE_OUT" <<'PY'
import json
import sys

decide = json.loads(sys.argv[1])
bridge = json.loads(sys.argv[2])
print(json.dumps({"bridge": bridge, "bridge_rc": 0, "decide_rc": 0 if decide.get("success") else 1}, separators=(",", ":")))
PY
