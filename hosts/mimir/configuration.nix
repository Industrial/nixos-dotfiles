# Mimir system configuration (file server)
{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
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
    ../../features/nixos/graphics/amd.nix
    ../../features/hardware/zsa-voyager
    ../../features/window-manager/hyprland
    ../../features/fleet/remote-access.nix
  ];
}
