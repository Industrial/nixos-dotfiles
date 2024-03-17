# Ripgrep searches in files. It's a replacement for grep.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    ripgrep
  ];
}
