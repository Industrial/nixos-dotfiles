# AI Profile
# Desktop/local AI apps only. Project agent CLIs (maestro, serena, hermes,
# context7, lean-ctx, roam, omniroute) come from `.cursor/nix` in product devenvs.
{
  config,
  lib,
  pkgs,
  inputs,
  settings,
  ...
}: {
  imports = [
    # ../features/ai/litellm
    # ../features/ai/n8n
    # ../features/ai/ollama
    # ../features/ai/anythingllm-desktop
    ../features/ai/claude-code
    ../features/ai/lmstudio
    ../features/ai/opencode
  ];
}
