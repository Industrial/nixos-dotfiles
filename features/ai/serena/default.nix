# serena — AI coding agent with LSP-based code intelligence and MCP server
# https://github.com/oraios/serena
#
# Provides `serena` on PATH as a NixOS system package.
# Hermes MCP server entry: command: serena  args: [start-mcp-server]
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {})
  ];
}
