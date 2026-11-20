# Huginn system configuration (tablet)
{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./filesystems.nix
    ./hardware.nix
  ];

  # profiles.ai.enable = true;
  profiles.base.enable = true;
  profiles.communication.enable = true;
  # profiles.creative.enable = true;
  profiles.desktop.enable = true;
  profiles.development.enable = true;
  # profiles.gaming.enable = true;

  features.fleet.comin.enable = true;
  features.fleet.nix-remote-builder-server.enable = true;
  features.fleet.remote-access.enable = true;
  features.monitoring.prometheus-exporter.enable = true;
  # Huginn is an Intel N200 (Alder Lake-N) tablet, not an AMD machine like the rest of the
  # fleet — see features/nixos/graphics/intel.nix.
  features.nixos.graphics.intel.enable = true;
  features.storage.nfs-client.enable = true;
}
