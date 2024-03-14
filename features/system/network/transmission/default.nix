# Bittorrent client.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    transmission-gtk
  ];
}
