{...}: {
  systemd = {
    network = {
      networks = {
        "31-vm_target" = {
          matchConfig = {
            Name = "vm_target";
          };

          address = [
            "10.0.0.0/32"
          ];

          routes = [
            {
              Destination = "10.0.0.3/32";
            }
          ];

          networkConfig = {
            IPv4Forwarding = true;
          };
        };
      };
    };
  };
}
