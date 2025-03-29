{pkgs, ...}: {
  # Configure the tap interfaces for each VM with static addressing
  systemd = {
    network = {
      networks = {
        # VM Web Server (10.0.0.1/32)
        "30-vm_web" = {
          matchConfig = {
            Name = "vm_web";
          };

          # Host's addresses on this interface
          address = [
            "10.0.0.0/32"
          ];

          # Routes to the VM
          routes = [
            {
              routeConfig = {
                Destination = "10.0.0.1/32";
              };
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

      # Port forwarding for the web server (vm_web)
      forwardPorts = [
        {
          destination = "10.0.0.1:80";
          proto = "tcp";
          sourcePort = 5080; # Host port
        }
        {
          destination = "10.0.0.1:443";
          proto = "tcp";
          sourcePort = 5443; # Host port
        }
      ];
    };

    # Firewall rules to control VM-to-VM communication
    firewall = {
      # Open ports on the host for the forwarded services
      allowedTCPPorts = [5022 5080 5443];
      # # Allow vm_web (Web Server) to access vm_database (Database Server)
      # extraCommands = ''
      #   # vm_web to vm_database access (database connections)
      #   iptables -A FORWARD -s 10.0.1.1/32 -d 10.0.2.1/32 -p tcp --dport 5432 -j ACCEPT
      #   #ip6tables -A FORWARD -s fd01::1/128 -d fd02::1/128 -p tcp --dport 5432 -j ACCEPT
      # '';
    };
  };
}
