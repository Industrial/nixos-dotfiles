# Huginn system configuration (tablet)
{...}: {
  imports = [
    ./filesystems.nix
    ./hardware.nix
    ../../profiles/ai.nix
    ../../profiles/base.nix
    ../../profiles/communication.nix
    #../../profiles/creative.nix
    ../../profiles/desktop.nix
    ../../profiles/development.nix
    ../../profiles/gaming.nix
    #../../profiles/learning.nix
    ../../features/window-manager/hyprland
    ../../features/fleet/remote-access.nix
  ];
}
