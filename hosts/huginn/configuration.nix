# Huginn system configuration (tablet)
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

    ../../features/fleet/comin.nix
    ../../features/fleet/nix-remote-builder-server.nix
    ../../features/fleet/remote-access.nix
    ../../features/monitoring/prometheus-exporter/default.nix
    # Huginn is an Intel N200 (Alder Lake-N) tablet, not an AMD machine like the rest of the
    # fleet — see features/nixos/graphics/intel.nix.
    ../../features/nixos/graphics/intel.nix
    ../../features/storage/nfs-client
  ];
}
