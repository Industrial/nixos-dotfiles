# Drakkar system configuration (desktop)
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
    ../../profiles/learning.nix
    ../../features/nixos/graphics/amd.nix
    ../../features/hardware/zsa-voyager
    ../../features/window-manager/hyprland
    ../../features/fleet/remote-access.nix
    ../../features/storage/nfs-client
    ../../features/fleet/nix-remote-builder-server.nix
  ];

  nixpkgs.overlays = [
    (final: prev: {
      python3Packages =
        prev.python3Packages
        // {
          nanoemoji = prev.python3Packages.nanoemoji.overrideAttrs (_old: {
            hash = "sha256-FysyKC01XBnRiur5RR9fcsTxQqE8x0JJHSoe3q6JtKc=";
          });
        };
    })
  ];
}
