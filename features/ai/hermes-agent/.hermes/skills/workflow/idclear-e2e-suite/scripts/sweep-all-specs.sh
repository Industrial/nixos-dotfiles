#!/usr/bin/env bash
# Fail-safe full sweep of bin/e2e-serial.sh DEFAULT_E2E_SERIAL_SPECS.
# Runs ONE e2e-serial.sh invocation per spec (forward order preserved),
# records "<exit-code>\t<spec>" rows, NEVER aborts early (no set -e).
#
# Usage (bun is only on PATH inside devenv):
#   devenv shell -- bash .hermes/skills/workflow/idclear-e2e-suite/scripts/sweep-all-specs.sh
# Env overrides:
#   E2E_DIR  target app dir   (default /data/Code/idclear/monorepo/apps/e2e-test)
#   OUT_DIR  output directory (default "$E2E_DIR/.e2e-sweep")
set -uo pipefail

E2E_DIR="${E2E_DIR:-/data/Code/idclear/monorepo/apps/e2e-test}"
OUT_DIR="${OUT_DIR:-${E2E_DIR}/.e2e-sweep}"
RESULTS="${OUT_DIR}/results.tsv"
LOG="${OUT_DIR}/full-run.log"

if ! command -v bun >/dev/null 2>&1; then
    echo "error: bun not on PATH — run via: devenv shell -- bash $0" >&2
    exit 1
fi

cd "${E2E_DIR}" || exit 1
mkdir -p "${OUT_DIR}"
# Grep must handle ANNOTATED lines (#/## prefixes), not just bare ones —
# a fully-annotated list (the normal state after a sweep) has zero bare
# entries, and a bare-only pattern silently discovers 0 specs.
mapfile -t SPECS < <(grep -oE '#+[[:space:]]*tests/[^[:space:]]+\.spec\.ts|^[[:space:]]*tests/[^[:space:]]+\.spec\.ts' bin/e2e-serial.sh | sed 's/^#*[[:space:]]*//')
if [ "${#SPECS[@]}" -eq 0 ]; then
    echo "error: no spec paths discovered in bin/e2e-serial.sh DEFAULT_E2E_SERIAL_SPECS" >&2
    exit 1
fi
echo "sweep: ${#SPECS[@]} specs discovered from DEFAULT_E2E_SERIAL_SPECS" >"${LOG}"
: >"${RESULTS}"

i=0
for spec in "${SPECS[@]}"; do
    i=$((i + 1))
    echo "===== [${i}/${#SPECS[@]}] START ${spec} =====" >>"${LOG}"
    if [ "${i}" -eq 1 ]; then
        # First invocation also configures the Logto mock email connector.
        bash bin/e2e-serial.sh "${spec}" >>"${LOG}" 2>&1
    else
        # Connector setup restarts Logto every invocation; skip for specs 2..N.
        E2E_SKIP_LOGTO_MOCK_SETUP=1 bash bin/e2e-serial.sh "${spec}" >>"${LOG}" 2>&1
    fi
    rc=$?
    printf '%s\t%s\n' "${rc}" "${spec}" >>"${RESULTS}"
    echo "----- [${i}/${#SPECS[@]}] DONE rc=${rc} ${spec}" >>"${LOG}"
done

echo "sweep: all ${#SPECS[@]} specs executed; results: ${RESULTS}" >>"${LOG}"
awk -F'\t' '{if ($1 == 0) p++; else f++} END {printf "sweep: %d passed, %d failed\n", p, f}' "${RESULTS}"
