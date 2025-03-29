{
  settings,
  pkgs,
  ...
}: {
  # vm_database - Database Server Configuration
  microvm = {
    interfaces = [
      {
        type = "tap";
        id = "vm_database";
        mac = "02:00:00:02:00:01";
      }
    ];
  };

  # Network configuration
  networking = {
    useNetworkd = true;
    hostName = settings.hostname;
    firewall = {
      enable = true;
      allowedTCPPorts = [5432 22]; # PostgreSQL and SSH
    };
  };

  # Static IP configuration
  systemd.network.networks."10-eth" = {
    matchConfig.MACAddress = "02:00:00:02:00:01";
    address = [
      "10.0.2.1/32"
      "fd02::1/128"
    ];
    routes = [
      {
        routeConfig = {
          # Route to the host
          Destination = "10.0.2.0/32";
          GatewayOnLink = true;
        };
      }
      {
        routeConfig = {
          # Route to VM1 (Web Server)
          Destination = "10.0.1.1/32";
          Gateway = "10.0.2.0";
        };
      }
      {
        routeConfig = {
          # IPv6 route to VM1
          Destination = "fd01::1/128";
          Gateway = "fd02::";
        };
      }
      {
        routeConfig = {
          # Route to VM3 (Management)
          Destination = "10.0.3.1/32";
          Gateway = "10.0.2.0";
        };
      }
      {
        routeConfig = {
          # IPv6 route to VM3
          Destination = "fd03::1/128";
          Gateway = "fd02::";
        };
      }
    ];
    networkConfig = {
      # Use vm_web as DNS server if you set up DNS there, or use public DNS
      DNS = ["10.0.1.1" "9.9.9.9"];
    };
  };

  # Database configuration
  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    authentication = ''
      # Allow connections from VM1 (Web Server)
      host all all 10.0.1.1/32 md5
      host all all fd01::1/128 md5
      # Allow connections from VM3 (Management)
      host all all 10.0.3.1/32 md5
      host all all fd03::1/128 md5
    '';
    initialScript = pkgs.writeText "postgres-init.sql" ''
      CREATE USER ${username} WITH SUPERUSER PASSWORD 'password';
      CREATE DATABASE ${username} WITH OWNER ${username};
      CREATE DATABASE appdb WITH OWNER ${username};
    '';
  };

  # Enable SSH for management
  services.openssh.enable = true;
}
