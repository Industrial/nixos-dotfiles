# A virtual machine running Tor. Can be used from the host machine or other
# virtual machines.
# SSH: ssh tom@10.0.0.2
# Proxy: 10.0.0.2:9050
# Test: curl -s --socks5-hostname 10.0.0.2:9050 http://www.showmyip.gr
{settings, ...}: let
  id = "vm_tor";
  mac = "02:00:00:01:01:01";
  ip = "10.0.0.2";
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
    nameservers = ["${internal_ip}"];
    firewall = {
      enable = true;
      allowedTCPPorts = [
        # SSH
        22

        # Tor
        9050
        #9051
      ];

      allowedUDPPorts = [
        # DNS
        53
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
      };
    };
  };

  # Tor service configuration
  services = {
    tor = {
      enable = true;
      enableGeoIP = false;
      client = {
        enable = true;
        dns = {
          enable = true;
        };
        socksListenAddress = {
          addr = "${internal_ip}";
          port = 9050;
        };
      };
      torsocks = {
        enable = true;
      };
      settings = {
        DNSPort = [
          {
            addr = "${internal_ip}";
            port = 53;
          }
        ];
      };
    };
    resolved = {
      enable = true;
      fallbackDns = [""];
    };
  };
}
