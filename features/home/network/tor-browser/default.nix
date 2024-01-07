# Tor Browser Bundle.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    tor-browser-bundle-bin
  ];
}
