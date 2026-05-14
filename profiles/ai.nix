# AI Profile
{
  config,
  lib,
  pkgs,
  inputs,
  settings,
  ...
}: {
  imports = [
    ../features/ai/anythingllm-desktop
    ../features/ai/claude-code
    ../features/ai/gemini-cli
    ../features/ai/hermes-agent
    # ../features/ai/litellm
    ../features/ai/lmstudio
    # ../features/ai/n8n
    # ../features/ai/ollama
    ../features/ai/opencode
  ];
}
