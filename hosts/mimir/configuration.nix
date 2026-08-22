# Mimir system configuration (file server)
{inputs, ...}: {
    imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./filesystems.nix
    ./hardware.nix
    ../../profiles/server.nix
    ../../features/media/jellyfin/default.nix
    ../../features/media/lidarr/default.nix
    ../../features/media/sonarr/default.nix
    ../../features/media/radarr/default.nix
    ../../features/media/prowlarr/default.nix
    ../../features/media/qbittorrent/default.nix
    ../../features/media/readarr/default.nix
    ../../features/media/seerr/default.nix
    ../../features/media/invidious/default.nix
    ../../features/media/homarr/default.nix
    ../../features/monitoring/prometheus/default.nix
    ../../features/monitoring/grafana/default.nix
    ../../features/monitoring/prometheus-agent/default.nix
  ];
}
