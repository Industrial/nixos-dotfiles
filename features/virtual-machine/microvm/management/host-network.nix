{...}: {
  # Configure the tap interfaces for each VM with static addressing
  systemd = {
    network = {
      networks = {
        # VM Management Server (10.0.3.1/32, fd03::1/128)
        "30-vm_management" = {
          matchConfig.Name = "vm_management";
          # Host's addresses on this interface
          address = [
            "10.0.3.0/32"
            "fd03::/128"
          ];
          # Routes to the VM
          routes = [
            {
              Destination = "10.0.3.1/32";
            }
            {
              Destination = "fd03::1/128";
            }
          ];
          # Enable routing
          networkConfig = {
            IPv4Forwarding = true;
            IPv6Forwarding = true;
          };
        };
      };
    };
  };

  networking = {
    # NAT configuration for internet access
    nat = {
      # Grant internet access to management VM
      internalIPs = ["10.0.3.0/24"];

      # Port forwarding for the management server (Grafana)
      forwardPorts = [
        {
          destination = "10.0.3.1:3000";
          proto = "tcp";
          sourcePort = 3000; # Host port
        }
      ];
    };

    # Firewall rules to control VM-to-VM communication
    firewall = {
      extraCommands = ''
        # vm_management to vm_web access
        iptables -A FORWARD -s 10.0.3.1/32 -d 10.0.1.1/32 -j ACCEPT
        ip6tables -A FORWARD -s fd03::1/128 -d fd01::1/128 -j ACCEPT
      '';
    };
  };
}
