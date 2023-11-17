# Bittorrent client.
{pkgs, ...}: {
  home.packages = with pkgs; [
    transmission-gtk
  ];
}
