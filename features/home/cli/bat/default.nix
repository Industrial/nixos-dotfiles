# Bat is a replacement for Cat
{pkgs, ...}: {
  home.packages = with pkgs; [
    bat
  ];
}
