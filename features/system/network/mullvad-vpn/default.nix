# VPN Client.
{
  settings,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    mullvad-vpn
  ];
  networking.firewall.checkReversePath = "loose";
  networking.firewall.enable = true;
  networking.iproute2.enable = true;
  networking.wireguard.enable = true;
  services.mullvad-vpn.enable = true;
  services.mullvad-vpn.package = pkgs.mullvad-vpn;
  services.resolved.enable = true;
}
