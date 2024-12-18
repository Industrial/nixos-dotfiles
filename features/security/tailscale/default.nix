{
  settings,
  pkgs,
  ...
}: {
  services = {
    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };
  };

  networking =
    if pkgs.stdenv.isLinux
    then {
      nameservers = ["100.100.100.100"];
      search = ["${settings.hostname}"];

      extraHosts = ''
        100.89.5.118 jellyfin.drakkar
        100.89.5.118 baserow.drakkar
        100.89.5.118 pairdrop.drakkar
      '';

      firewall = {
        trustedInterfaces = ["tailscale0"];
      };
    }
    else {};
}
