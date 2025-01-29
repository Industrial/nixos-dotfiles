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

      # extraHosts = ''
      #   100.89.58.60 jellyfin.mimir
      #   100.89.58.60 baserow.mimir
      #   100.89.58.60 pairdrop.mimir
      # '';

      firewall = {
        trustedInterfaces = ["tailscale0"];
      };
    }
    else {};
}
