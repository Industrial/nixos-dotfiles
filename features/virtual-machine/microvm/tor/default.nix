{settings, ...}: {
  # vm_tor - Tor Configuration
  microvm = {
    interfaces = [
      {
        type = "tap";
        id = "vm_tor";
        mac = "02:00:00:01:00:02";
      }
    ];
  };

  # Network configuration
  networking = {
    useNetworkd = true;
    hostName = settings.hostname;
    firewall = {
      enable = true;
      # Tor port - adjust if needed
      allowedTCPPorts = [
        9050
        # TODO: Disable this one!
        9051
      ];
    };
  };

  # Static IP configuration
  systemd = {
    network = {
      networks = {
        "10-eth" = {
          matchConfig = {
            # New MAC address
            MACAddress = "02:00:00:01:00:02";
          };
          address = [
            # New IP address
            "10.0.0.2/32"
          ];
          routes = [
            {
              Destination = "10.0.0.0/32";
              GatewayOnLink = true;
            }
            {
              Destination = "0.0.0.0/0";
              Gateway = "10.0.0.0";
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
          addr = "0.0.0.0";
          port = 9050;
        };
      };
      torsocks = {
        enable = true;
      };
    };
  };

  # Use Tor for DNS.
  services = {
    tor = {
      settings = {
        DNSPort = [
          {
            addr = "127.0.0.1";
            port = 53;
          }
        ];
      };
    };
    resolved = {
      # For caching DNS requests.
      enable = true;
      # Overwrite compiled-in fallback DNS servers.
      fallbackDns = [""];
    };
  };
  networking = {
    nameservers = ["127.0.0.1"];
    firewall = {
      # DNS port - adjust if needed
      allowedUDPPorts = [53];
    };
  };
}
