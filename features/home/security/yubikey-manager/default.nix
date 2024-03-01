# YubiKey Manager (ykman-gui)
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    yubikey-manager
    yubikey-manager-qt
    yubikey-personalization-gui
  ];
}
