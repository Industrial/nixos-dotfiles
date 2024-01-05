# VPN Client.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    mullvad-vpn
  ];
  services.mullvad-vpn.package = pkgs.mullvad-vpn;
  networking.firewall.checkReversePath = "loose";
  networking.wireguard.enable = true;
  services.mullvad-vpn.enable = true;
  networking.iproute2.enable = true;
  services.resolved.enable = true;
}
