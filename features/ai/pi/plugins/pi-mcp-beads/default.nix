# pi-mcp-beads — stdio MCP server for Beads (bd) in Pi
{pkgs}:
  pkgs.writeShellScriptBin "pi-mcp-beads" ''
    exec "$HOME/.dotfiles/features/ai/pi/bin/pi-mcp-beads" "$@"
  ''
