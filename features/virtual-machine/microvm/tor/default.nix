{
  settings,
  pkgs,
  ...
}: {
  # vm_tor - Tor Configuration
  microvm = {
    interfaces = [
      {
        type = "tap";
        id = "vm_tor";
        # New MAC address
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
      # DNS port - adjust if needed
      allowedUDPPorts = [53];
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
      # settings = {
      #   SOCKSPort = 9050;
      #   ControlPort = 9051;
      # };
      # Disable GeoIP to prevent the Tor client from estimating the locations of
      # Tor nodes it connects to
      enableGeoIP = false;
      client = {
        enable = true;
        dns = {
          enable = true;
        };
        # socksListenAddress = {
        #   IsolateDestAddr = true;
        #   addr = "127.0.0.1";
        #   port = 9050;
        # };
      };
      torsocks = {
        enable = true;
        # server = "127.0.0.1:9050";
        # fasterServer = "127.0.0.1:9063";
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
  };
}
