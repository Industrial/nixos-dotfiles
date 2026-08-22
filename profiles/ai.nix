# AI Profile
# Desktop/local AI apps + hermes-agent (system). Project agent CLIs
# (maestro, serena, context7, lean-ctx, roam, omniroute) come from
# `.cursor/nix` in product devenvs — not from features/ai.
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
    # ../features/ai/claude-code
    #../features/ai/hermes-agent
    # ../features/ai/litellm
    # ../features/ai/lmstudio
    # ../features/ai/n8n
    # ../features/ai/ollama
    #../features/ai/opencode
    #../features/ai/paperclip
  ];
}
