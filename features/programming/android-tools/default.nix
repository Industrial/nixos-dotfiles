# Android Developer Tools.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    android-tools
  ];
}
