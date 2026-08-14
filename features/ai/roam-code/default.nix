# roam-code — AI-native code intelligence MCP server
# https://github.com/Cranot/roam-code
#
# Provides `roam` on PATH as a NixOS system package.
# Hermes MCP server entry: command: roam  args: [mcp]
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {})
  ];
}
