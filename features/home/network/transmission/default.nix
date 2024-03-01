# Bittorrent client.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    transmission-gtk
  ];
}
