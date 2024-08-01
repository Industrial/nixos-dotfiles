args @ {settings, ...}: let
  feature = import ./default.nix args;
in {
  networking = {
    hostName = {
      test = {
        expr = feature.networking.hostName;
        expected = settings.hostname;
      };
    };
    networkmanager = {
      enable = {
        test = {
          expr = feature.networking.networkmanager.enable;
          expected = true;
        };
      };
    };
    firewall = {
      enable = {
        test = {
          expr = feature.networking.firewall.enable;
          expected = true;
        };
      };
      allowedTCPPorts = {
        test = {
          expr = feature.networking.firewall.allowedTCPPorts;
          expected = [];
        };
      };
      allowedUDPPorts = {
        test = {
          expr = feature.networking.firewall.allowedUDPPorts;
          expected = [];
        };
      };
    };
  };
}
