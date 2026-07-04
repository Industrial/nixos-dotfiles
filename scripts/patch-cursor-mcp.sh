#!/usr/bin/env bash
# Idempotent dotfiles overlay for Industrial/cursor-setup mcp.json.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MCP_JSON="$REPO_ROOT/.cursor/mcp.json"

[[ -f "$MCP_JSON" ]] || exit 0

python3 << PY
import json
from pathlib import Path

path = Path("$MCP_JSON")
data = json.loads(path.read_text())
servers = data["mcpServers"]

servers["serena"] = {
    "type": "stdio",
    "command": "bash",
    "args": ["scripts/serena-mcp-wrapper.sh", "--project-from-cwd", "--log-level", "WARNING"],
    "disabled": False,
    "description": "Serena MCP (@oraios/serena); run devenv shell once so .devenv/state/venv exists",
}

for name in ("postgres", "temporal", "figma-mcp-go", "playwright", "chrome-devtools", "maestro"):
    if name in servers:
        servers[name]["disabled"] = True

path.write_text(json.dumps(data, indent="\t") + "\n")
PY
