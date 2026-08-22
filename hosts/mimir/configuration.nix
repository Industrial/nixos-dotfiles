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
    ../../features/monitoring/prometheus-exporter/default.nix
    ../../features/monitoring/prometheus/default.nix
    ../../features/nixos/graphics/amd.nix
    ../../features/storage/nfs-server

    # ../../features/media/jellyfin/default.nix
    # ../../features/media/lidarr/default.nix
    # ../../features/media/sonarr/default.nix
    # ../../features/media/radarr/default.nix
    # ../../features/media/prowlarr/default.nix
    # ../../features/media/qbittorrent/default.nix
    # ../../features/media/readarr/default.nix
    # ../../features/media/seerr/default.nix
    # ../../features/media/invidious/default.nix
    # ../../features/media/homarr/default.nix
  ];
}
