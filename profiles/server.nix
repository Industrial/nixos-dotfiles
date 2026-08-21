# Server Profile — Mimir (storage + KVM admin, no gaming/AI)
{...}: {
  imports = [
    ./base.nix
    ./communication.nix
    ./desktop.nix
    ./development.nix
    ../features/nixos/graphics/amd.nix
    ../features/hardware/zsa-voyager
    ../features/window-manager/hyprland
    ../features/fleet/remote-access.nix
    ../features/storage/nfs-server
  ];
}
