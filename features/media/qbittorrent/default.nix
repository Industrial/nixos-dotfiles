# QBittorrent desktop BitTorrent client
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    qbittorrent
  ];
}
