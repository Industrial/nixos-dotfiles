# Mimir system configuration (file server)
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
    #../../profiles/learning.nix

    ../../features/fleet/nix-remote-builder-client.nix
    ../../features/fleet/remote-access.nix
    ../../features/monitoring/grafana/default.nix
    ../../features/monitoring/homepage-dashboard
    ../../features/monitoring/prometheus-exporter/default.nix
    ../../features/monitoring/prometheus/default.nix
    ../../features/nixos/graphics/amd.nix
    ../../features/storage/nfs-server

    # ../../features/media/jellyfin/default.nix
    # ../../features/media/flexget/default.nix
    # ../../features/media/jackett/default.nix
    ../../features/media/qbittorrent-nox/default.nix
    # ../../features/media/transmission/default.nix
    # ../../features/media/seerr/default.nix
    # ../../features/media/invidious/default.nix
  ];
}
