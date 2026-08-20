# Hermes Agent — https://hermes-agent.org/
# Nix-native build (not the upstream curl installer). See package.nix for pins and nixpkgs notes.
#
# Imports the following MCP server features so they are guaranteed on PATH:
# Plugins (hermes_agent.plugins entry-point packages):
#   cursor-acp (./plugins/cursor-acp) — Cursor CLI ACP model provider
{pkgs, ...}: {
  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {
      # Plugins are injected as propagatedBuildInputs so Hermes discovers them
      # via importlib.metadata (hermes_agent.plugins entry point) at session start.
      extraPlugins = [
        (pkgs.callPackage ./plugins/cursor-acp/package.nix {})
      ];
    })
  ];
}
