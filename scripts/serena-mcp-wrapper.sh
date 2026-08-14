#!/usr/bin/env bash
# Serena MCP (stdio): use the project uv venv directly so Cursor does not need
# the devenv shell PATH, and keep Nix Python packages out of the venv runtime.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERENA="$REPO_ROOT/.devenv/state/venv/bin/serena"

if [[ ! -x "$SERENA" ]]; then
    echo "serena-mcp-wrapper: missing $SERENA; run 'devenv shell' once to sync the uv venv" >&2
    exit 127
fi

cd "$REPO_ROOT"
export PATH="$REPO_ROOT/.devenv/state/venv/bin:$REPO_ROOT/.devenv/profile/bin:${PATH:-}"
unset PYTHONPATH

RUST_ANALYZER="$(command -v rust-analyzer || true)"
if [[ -x "$RUST_ANALYZER" ]]; then
    SERENA_RA_DIR="$HOME/.serena/language_servers/static/RustAnalyzer/RustAnalyzer"
    mkdir -p "$SERENA_RA_DIR"
    {
        printf '#!/usr/bin/env bash\n'
        printf 'exec %q "$@"\n' "$RUST_ANALYZER"
    } >"$SERENA_RA_DIR/rust_analyzer"
    chmod +x "$SERENA_RA_DIR/rust_analyzer"
fi

if [[ $# -eq 0 ]]; then
    set -- --project-from-cwd --log-level WARNING
else
    has_project=false
    for arg in "$@"; do
        if [[ "$arg" == "--project" || "$arg" == "--project-from-cwd" ]]; then
            has_project=true
            break
        fi
    done
    if [[ "$has_project" == false ]]; then
        set -- --project-from-cwd "$@"
    fi
fi

exec "$SERENA" start-mcp-server "$@"
