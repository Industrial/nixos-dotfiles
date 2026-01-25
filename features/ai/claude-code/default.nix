# Claude Code - Agentic coding tool from Anthropic.
{pkgs, ...}: {
  environment = {
    systemPackages = with pkgs; [
      claude-code
    ];
  };
}
