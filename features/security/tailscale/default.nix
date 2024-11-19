{stdenv, ...}: {
  services = {
    tailscale = {
      enable = true;
    };
  };

  networking =
    if stdenv.isLinux
    then {
      firewall = {
        trustedInterfaces = ["tailscale0"];
      };
    }
    else {};
}
