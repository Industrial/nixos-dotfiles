# context7 — MCP server for up-to-date library documentation context
# https://github.com/upstash/context7
#
# Provides `context7-mcp` on PATH as a NixOS system package.
# Hermes MCP server entry: command: context7-mcp  args: []
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {})
  ];
}
