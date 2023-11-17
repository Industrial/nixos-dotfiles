# Btop is a htop replacement
{pkgs, ...}: {
  home.packages = with pkgs; [
    btop
  ];
}
