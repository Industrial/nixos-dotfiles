{settings, ...}: {
  services = {
    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };
  };

  networking = {
    nameservers = ["100.100.100.100"];
    search = ["${settings.hostname}"];

    firewall = {
      trustedInterfaces = ["tailscale0"];
    };
  };
}
