# Drakkar system configuration (desktop)
{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./filesystems.nix
    ./hardware.nix

    # ../../profiles/ai.nix
    ../../profiles/base.nix
    ../../profiles/communication.nix
    #../../profiles/creative.nix
    ../../profiles/desktop.nix
    ../../profiles/development.nix
    #../../profiles/gaming.nix
    ../../profiles/learning.nix

    ../../features/fleet/nix-remote-builder-server.nix
    ../../features/fleet/remote-access.nix
    ../../features/monitoring/prometheus-exporter/default.nix
    ../../features/nixos/graphics/amd.nix
    ../../features/storage/nfs-client
  ];
}
