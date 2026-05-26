# Hermes Agent — https://hermes-agent.org/
# Nix-native build (not the upstream curl installer). See package.nix for pins and nixpkgs notes.
#
# Imports the following MCP server features so they are guaranteed on PATH:
#   lean-ctx   (../lean-ctx)   — context compression + 42 MCP tools (issue #112, v3.2.4+)
#   roam-code  (../roam-code)  — AI-native code intelligence via tree-sitter
#   serena     (../serena)     — LSP-based coding agent with MCP server
#   context7   (../context7)   — up-to-date library documentation context
#
# Plugins (hermes_agent.plugins entry-point packages):
#   id-hermes-superpowers (./plugins/id-hermes-superpowers) — Superpowers agentic workflows
{pkgs, ...}: {
  imports = [
    ../lean-ctx
    ../roam-code
    ../serena
    ../context7
  ];

  environment.systemPackages = [
    (pkgs.callPackage ./package.nix {
      # Plugins are injected as propagatedBuildInputs so Hermes discovers them
      # via importlib.metadata (hermes_agent.plugins entry point) at session start.
      extraPlugins = [
        (pkgs.callPackage ./plugins/id-hermes-superpowers/package.nix {})
      ];
    })
  ];
}
