{...}: {
  # Configure the tap interfaces for each VM with static addressing
  systemd = {
    network = {
      networks = {
        # VM Database Server (10.0.2.1/32, fd02::1/128)
        "30-vm_database" = {
          matchConfig.Name = "vm_database";
          # Host's addresses on this interface
          address = [
            "10.0.2.0/32"
            "fd02::/128"
          ];
          # Routes to the VM
          routes = [
            {
              Destination = "10.0.2.1/32";
            }
            {
              Destination = "fd02::1/128";
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
    # Firewall rules to control VM-to-VM communication
    firewall = {
      # Block VM2 from initiating connections to the internet
      extraCommands = ''
        # Block vm_database from initiating connections to the internet
        iptables -A FORWARD -s 10.0.2.1/32 ! -d 10.0.0.0/8 -j DROP
        ip6tables -A FORWARD -s fd02::1/128 ! -d fd00::/8 -j DROP

        # Allow vm_management to access vm_database
        iptables -A FORWARD -s 10.0.3.1/32 -d 10.0.2.1/32 -j ACCEPT
        ip6tables -A FORWARD -s fd03::1/128 -d fd02::1/128 -j ACCEPT
      '';
    };
  };
}
