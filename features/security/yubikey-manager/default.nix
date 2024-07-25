# YubiKey Manager (ykman-gui)
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    yubikey-manager
    yubikey-manager-qt
    yubikey-personalization-gui
  ];
}
