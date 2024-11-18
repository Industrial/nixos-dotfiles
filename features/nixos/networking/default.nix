{settings, ...}: {
  networking = {
    hostName = settings.hostname;
    networkmanager = {
      enable = true;
      dns = "none";
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [];
      allowedUDPPorts = [];
    };
  };
}
