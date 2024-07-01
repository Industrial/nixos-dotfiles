# Bat is a replacement for Cat
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    bat
  ];
}
