{pkgs, ...}: {
  # Configure the tap interfaces for each VM with static addressing
  systemd = {
    network = {
      networks = {
        # VM Target (10.0.0.3/32)
        "31-vm_target" = {
          matchConfig = {
            Name = "vm_target";
          };

          # Host's addresses on this interface
          address = [
            "10.0.0.0/32"
          ];

          # Routes to the VM
          routes = [
            {
              Destination = "10.0.0.3/32";
              GatewayOnLink = true;
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
}
