# AI Profile
# Desktop/local AI apps. (hermes-agent was retired 2026-10-13.)
#
# claude-code is system-wide: it owns ~/.claude and imports the MCP server
# features its .claude/mcp.json declares (lean-ctx, roam-code, maestro,
# context7). Product devenvs still provision their own copies via
# `.cursor/nix` — the two are independent and may pin different versions.
# serena and omniroute remain devenv-only.
{
  config,
  lib,
  pkgs,
  inputs,
  settings,
  ...
}: {
  imports = [
    # ../features/ai/anythingllm-desktop
    ../features/ai/claude-code
    # Paseo — the chosen browser surface over this host's coding agents. Binds
    # 127.0.0.1:6767. In the profile rather than per-host because it is useful
    # wherever claude-code is, and both drakkar and muninn import this profile.
    ../features/ai/paseo
    # CloudCLI — superseded by paseo above and disabled rather than deleted, so
    # the work and its notes survive if paseo disappoints. Same niche exactly: a
    # browser over the agents already configured here. Running both would mean two
    # daemons watching the same ~/.claude session files and two ports to remember,
    # so they are mutually exclusive by intent, not by accident.
    # ../features/ai/cloudcli
    # ../features/ai/litellm
    # ../features/ai/lmstudio
    # ../features/ai/n8n
    # OpenHands Agent Canvas. Commented here and imported directly by
    # hosts/drakkar/configuration.nix instead: muninn imports this profile too, and Canvas
    # belongs on the desktop only — it is the host with the RAM and the Docker cache, and
    # the one where somebody is sitting in front of the UI.
    # ../features/ai/openhands
    # ../features/ai/ollama
    #../features/ai/opencode
    #../features/ai/paperclip
  ];
}
