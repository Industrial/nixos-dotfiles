# A virtual machine running a service that connects to the internet.
{
  settings,
  pkgs,
  ...
}: let
  id = "vm_target";
  in_mac = "02:00:00:01:02:01";
  out_mac = "02:00:00:01:02:02";
  mac = "02:00:00:01:00:03";
  ip = "10.0.0.3";
  gateway_ip = "10.0.0.0";
  tor_ip = "10.0.0.2";
  internal_ip = "0.0.0.0";
in {
  microvm = {
    interfaces = [
      {
        type = "tap";
        id = id;
        mac = mac;
      }
      {
        type = "tap";
        id = "in";
        mac = in_mac;
      }
      # {
      #   type = "tap";
      #   id = "out";
      #   mac = out_mac;
      # }
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
      ];
    };
  };

  systemd = {
    network = {
      networks = {
        "10-in" = {
          matchConfig = {
            MACAddress = mac;
          };
          address = [
            "${ip}/32"
          ];
          routes = [
            {
              Destination = "${gateway_ip}/32";
              GatewayOnLink = true;
            }
            {
              Destination = "${internal_ip}/0";
              Gateway = "${gateway_ip}";
              GatewayOnLink = true;
            }
          ];
          networkConfig = {
            DNS = ["9.9.9.9" "149.112.112.112"];
          };
        };
        # "10-in" = {
        #   matchConfig = {
        #     MACAddress = in_mac;
        #   };
        #   address = [
        #     "${ip}/32"
        #   ];
        #   routes = [
        #     {
        #       Destination = "${gateway_ip}/32";
        #       GatewayOnLink = true;
        #     }
        #     {
        #       Destination = "${internal_ip}/0";
        #       Gateway = "${gateway_ip}";
        #       GatewayOnLink = true;
        #     }
        #     # {
        #     #   Source = "${gateway_ip}/0";
        #     #   Destination = "${ip}/0";
        #     # }
        #   ];
        #   networkConfig = {
        #     DNS = ["9.9.9.9" "149.112.112.112"];
        #   };
        # };
        # "20-out" = {
        #   matchConfig = {
        #     MACAddress = out_mac;
        #   };
        #   address = [
        #     "${ip}/32"
        #   ];
        #   routes = [
        #     {
        #       Destination = "${internal_ip}/0";
        #       Gateway = "${tor_ip}";
        #       GatewayOnLink = true;
        #     }
        #   ];
        #   networkConfig = {
        #     DNS = ["${tor_ip}"];
        #   };
        # };
      };
    };
  };

  environment = {
    systemPackages = with pkgs; [
      # Network testing tools
      curl # for HTTP requests
      dig # DNS lookup
      inetutils # for hostname, ping, etc.
      iproute2 # for ip command
      jq # for JSON processing
      netcat # for testing TCP connections
      traceroute # for tracing network routes
    ];
  };
}
