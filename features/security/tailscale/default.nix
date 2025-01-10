{
  settings,
  pkgs,
  ...
}: {
  services = {
    tailscale =
      if pkgs.stdenv.isLinux
      then {
        enable = true;
        useRoutingFeatures = "client";
      }
      else {
        enable = true;
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
