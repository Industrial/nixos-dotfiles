# Ripgrep searches in files. It's a replacement for grep.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    ripgrep
  ];
}
