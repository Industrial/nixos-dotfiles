#!/usr/bin/env bash
# roam MCP (stdio): `roam mcp` from devenv.nix (roam-code 11+ + fastmcp).
# Cursor resolves tools from host PATH without devenv; this wrapper forces the project binary.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"
exec devenv shell -- roam mcp "$@"
