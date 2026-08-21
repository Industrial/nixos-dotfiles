# Mobile Profile — Huginn (tablet, no gaming/AI)
{...}: {
  imports = [
    ./base.nix
    ./communication.nix
    ./desktop.nix
    ./development.nix
    ../features/window-manager/hyprland
    ../features/fleet/remote-access.nix
    ../features/storage/nfs-client
    ../features/fleet/nix-remote-builder-client.nix
  ];
}
