# Muninn system configuration (work laptop)
# Acts as monitoring standby when mimir is down.
# No personal files here: it does not mount mimir's NFS (see filesystems.nix).
{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./filesystems.nix
    ./hardware.nix
  ];

  profiles.ai.enable = true;
  profiles.base.enable = true;
  profiles.communication.enable = true;
  # profiles.creative.enable = true;
  profiles.desktop.enable = true;
  profiles.development.enable = true;
  # profiles.gaming.enable = true;

  features.fleet.comin.enable = true;
  features.fleet.nix-remote-builder-server.enable = true;
  features.fleet.remote-access.enable = true;
  features.monitoring.grafana.enable = true;
  features.monitoring.homepage-dashboard.enable = true;
  features.monitoring.prometheus-exporter.enable = true;
  features.monitoring.prometheus.enable = true;
  features.nixos.graphics.amd.enable = true;
}
