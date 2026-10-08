# Claude Desktop - Official Linux beta
# Uses the poeck/claude-desktop-nix-flake to package Anthropic's official .deb
{inputs, ...}: {
  imports = [
    inputs.claude-desktop.nixosModules.default
  ];

  programs.claude-desktop.enable = true;
}
