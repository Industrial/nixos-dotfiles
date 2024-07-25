# Android Developer Tools.
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    android-tools
  ];
}
