# YubiKey Manager (ykman-gui)
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    yubikey-manager
    yubikey-manager-qt
    yubikey-personalization-gui
  ];
}
