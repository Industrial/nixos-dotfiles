# Ripgrep searches in files. It's a replacement for grep.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    ripgrep
  ];
}
