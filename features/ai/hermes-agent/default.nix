# Hermes Agent — https://hermes-agent.org/
# Nix-native build (not the upstream curl installer). See package.nix for pins and nixpkgs notes.
#
# Includes lean-ctx (../lean-ctx) so the lean-ctx MCP server is guaranteed on PATH whenever
# hermes is present. Issue #112 in lean-ctx adds native Hermes support (v3.2.4+):
#   lean-ctx init --agent hermes --global   → writes mcp_servers entry to ~/.hermes/config.yaml
#   lean-ctx setup                          → auto-detects ~/.hermes/ and configures it
#   lean-ctx doctor                         → Hermes appears in MCP config check
{pkgs, ...}: {
  imports = [
    ../lean-ctx
  ];

  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {})
  ];
}
