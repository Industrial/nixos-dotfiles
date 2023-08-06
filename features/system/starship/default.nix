# Starship is a shell prompt.
# This must be installed in system packages for fish to pick it up.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    starship
  ];
}
