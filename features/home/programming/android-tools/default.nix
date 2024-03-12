# Android Developer Tools.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    android-tools
  ];
}
