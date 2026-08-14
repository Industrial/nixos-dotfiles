#!/usr/bin/env bash
# probe-gateway.sh — verify Hermes routing through the local omniroute gateway.
# Usage: bash probe-gateway.sh [ALIAS]
#   ALIAS defaults to auto/best-free (the "any free model" alias).
# Never test against the OpenRouter public API here — the gateway has its own
# credential pool and the two differ.
set -u
GW="${OMNIROUTE_GATEWAY:-http://127.0.0.1:20128/v1}"
KEY="${OMNIROUTE_API_KEY:-${OMNIROUTE_API_KEY:-}}"
ALIAS="${1:-auto/best-free}"

if [ -z "$KEY" ]; then
    # fall back to the key exported in the shell / .env if present
    KEY="$(grep -h 'OMNIROUTE_API_KEY' ~/.hermes/.env 2>/dev/null | head -1 | cut -d= -f2-)"
fi
[ -z "$KEY" ] && { echo "ERROR: OMNIROUTE_API_KEY not set"; exit 2; }

echo "=== gateway /v1/models (ids only) ==="
curl -s --max-time 8 "$GW/models" | python3 -c \
    "import sys,json; d=json.load(sys.stdin); [print(m['id']) for m in d.get('data',[])]" 2>&1 | head -60

echo
echo "=== probe: $ALIAS ==="
curl -s --max-time 45 "$GW/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $KEY" \
    -d "{\"model\":\"$ALIAS\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: OK\"}],\"max_tokens\":10}" \
| python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
except Exception as e:
    print('PARSE ERROR:', e); sys.exit(1)
err=d.get('error',{})
if err:
    print('ERR:', err.get('message'), '|', err.get('type'), err.get('code'))
else:
    c=d.get('choices',[{}])[0].get('message',{}).get('content','')
    print('OK:', repr(c))
"
