# Ripgrep searches in files. It's a replacement for grep.
{pkgs, ...}: {
  home.packages = with pkgs; [
    ripgrep
  ];
}
