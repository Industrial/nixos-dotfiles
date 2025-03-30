{pkgs, ...}: {
  # Configure the tap interfaces for each VM with static addressing
  systemd = {
    network = {
      networks = {
        # VM Tor (10.0.0.2/32)
        "30-vm_tor" = {
          matchConfig = {
            Name = "vm_tor";
          };

          # Host's addresses on this interface
          address = [
            "10.0.0.0/32"
          ];

          # Routes to the VM
          routes = [
            {
              Destination = "10.0.0.2/32";
            }
          ];

          # Enable routing
          networkConfig = {
            IPv4Forwarding = true;
          };
        };
      };
    };
  };

  networking = {
    # NAT configuration for internet access
    nat = {
      # Grant internet access
      internalIPs = ["10.0.0.0/24"];

      # Port forwarding for the tor server (vm_tor)
      forwardPorts = [
        {
          destination = "10.0.0.2:9050";
          proto = "tcp";
          sourcePort = 9050; # Host port
        }
        {
          destination = "10.0.0.2:9051";
          proto = "tcp";
          sourcePort = 9051; # Host port
        }
        {
          destination = "10.0.0.2:53";
          proto = "udp";
          sourcePort = 53; # Host port
        }
      ];
    };

    # Firewall rules to control VM-to-VM communication
    firewall = {
      # Open ports on the host for the forwarded services
      allowedTCPPorts = [9050 9051];
      allowedUDPPorts = [53];
    };
  };
}
