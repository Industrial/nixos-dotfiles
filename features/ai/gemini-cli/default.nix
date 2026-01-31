# Gemini CLI - AI agent that brings the power of Gemini directly into your terminal.
{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      gemini-cli
    ];
  };
}
