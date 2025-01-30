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

      firewall = {
        trustedInterfaces = ["tailscale0"];
      };
    }
    else {};
}
