{...}: {
  systemd = {
    network = {
      networks = {
        "30-vm_tor" = {
          matchConfig = {
            Name = "vm_tor";
          };

          address = [
            "10.0.0.0/32"
          ];

          routes = [
            {
              Destination = "10.0.0.2/32";
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
