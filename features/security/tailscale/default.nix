{pkgs, ...}: {
  services = {
    tailscale = {
      enable = true;
    };
  };

  networking =
    if pkgs.stdenv.isLinux
    then {
      firewall = {
        trustedInterfaces = ["tailscale0"];
      };
    }
    else {};
}
