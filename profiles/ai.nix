# AI Profile
# Desktop/local AI apps + hermes-agent (system).
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
    #../features/ai/hermes-agent
    # ../features/ai/litellm
    # ../features/ai/lmstudio
    # ../features/ai/n8n
    # ../features/ai/ollama
    #../features/ai/opencode
    #../features/ai/paperclip
  ];
}
