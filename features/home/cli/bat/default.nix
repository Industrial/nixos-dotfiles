# Bat is a replacement for Cat
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    bat
  ];
}
