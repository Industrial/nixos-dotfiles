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
    ../features/ai/claude-code
    ../features/ai/gemini-cli
    ../features/ai/litellm
    ../features/ai/n8n
    ../features/ai/ollama
    ../features/ai/opencode
  ];
}
