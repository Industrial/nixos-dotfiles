# Mullvad VPN.
{
  settings,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    mullvad-vpn
  ];
}
