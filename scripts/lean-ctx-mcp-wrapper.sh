#!/usr/bin/env bash
# lean-ctx MCP (stdio): binary from devenv.nix (`lean-ctx` package).
# Cursor / IDE: reference this path in `.cursor/mcp.json` / `.mcp.json`.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"
exec devenv shell -- lean-ctx "$@"
