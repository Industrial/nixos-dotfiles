# Huginn system configuration (tablet)
{...}: {
  imports = [
    ./filesystems.nix
    ./hardware.nix
    ../../profiles/base.nix
    ../../profiles/development.nix
    ../../profiles/desktop.nix
    ../../profiles/communication.nix
    ../../profiles/learning.nix
    ../../features/window-manager/hyprland
    ../../features/fleet/remote-access.nix
  ];
}
