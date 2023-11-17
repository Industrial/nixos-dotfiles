# Direnv sources nix environments in project directories as you cd into them.
{pkgs, ...}: {
  home.packages = with pkgs; [
    direnv
  ];
}
