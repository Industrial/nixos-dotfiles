# A virtual machine running a service that connects to the internet. It is
# routed through the vm_tor vm proving that it can only connect to the internet
# through tor.
# SSH: ssh tom@10.0.0.3
{
  settings,
  pkgs,
  ...
}: let
  id = "vm_target";
  mac = "02:00:00:01:00:03";
  ip = "10.0.0.3";
  gateway_ip = "10.0.0.0";
  internal_ip = "0.0.0.0";
in {
  microvm = {
    interfaces = [
      {
        type = "tap";
        id = id;
        mac = mac;
      }
    ];
  };

  networking = {
    useNetworkd = true;
    hostName = settings.hostname;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        # SSH
        22

        # # Tor
        # 9050
        # #9051
      ];
    };
  };

  systemd = {
    network = {
      networks = {
        "10-eth" = {
          matchConfig = {
            MACAddress = mac;
          };
          address = [
            "${ip}/32"
          ];
          routes = [
            {
              Destination = "${gateway_ip}/32";
              Gateway = "${gateway_ip}";
              GatewayOnLink = true;
            }
            {
              Destination = "${internal_ip}/32";
              Gateway = true;
            }
            {
              Destination = "${internal_ip}/0";
              Gateway = "${gateway_ip}";
              GatewayOnLink = true;
            }
          ];
          networkConfig = {
            DNS = ["${internal_ip}"];
            # DNS = ["9.9.9.9" "149.112.112.112"];
          };
        };
      };
    };
  };

  environment = {
    systemPackages = with pkgs; [
      curl
      dig
    ];
  };
}
