# Bat is a replacement for Cat
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    bat
  ];
}
