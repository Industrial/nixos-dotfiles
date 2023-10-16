# YubiKey Manager (ykman-gui)
{pkgs, ...}: {
  home.packages = with pkgs; [
    yubikey-manager
    yubikey-manager-qt
    yubikey-personalization-gui
  ];
}
