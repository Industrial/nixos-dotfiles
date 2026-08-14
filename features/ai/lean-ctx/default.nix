# lean-ctx — Context Runtime for AI Agents
# https://github.com/yvgude/lean-ctx
#
# Provides `lean-ctx` on PATH as a NixOS system package.
# Hermes Agent MCP support added in v3.2.4 (issue #112):
#   lean-ctx init --agent hermes --global   → writes ~/.hermes/config.yaml mcp_servers entry
#   lean-ctx setup                          → auto-detects ~/.hermes/ and configures it
#   lean-ctx doctor                         → includes Hermes in MCP config check
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {})
  ];
}
