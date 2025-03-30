{
  settings,
  pkgs,
  ...
}: {
  # vm_management - Management Server Configuration
  microvm = {
    interfaces = [
      {
        type = "tap";
        id = "vm_management";
        mac = "02:00:00:03:00:01";
      }
    ];
  };

  # Network configuration
  networking = {
    useNetworkd = true;
    hostName = settings.hostname;
    firewall = {
      enable = true;
      allowedTCPPorts = [22 3000]; # SSH and Grafana
    };
  };

  # Static IP configuration
  systemd.network.networks."10-eth" = {
    matchConfig.MACAddress = "02:00:00:03:00:01";
    address = [
      "10.0.3.1/32"
      "fd03::1/128"
    ];
    routes = [
      {
        # Route to the host
        Destination = "10.0.3.0/32";
        GatewayOnLink = true;
      }
      {
        # Default route for limited internet access
        Destination = "0.0.0.0/0";
        Gateway = "10.0.3.0";
        GatewayOnLink = true;
      }
      {
        # IPv6 default route
        Destination = "::/0";
        Gateway = "fd03::";
        GatewayOnLink = true;
      }
      {
        # Route to VM1 (Web Server)
        Destination = "10.0.1.1/32";
        Gateway = "10.0.3.0";
      }
      {
        # IPv6 route to VM1
        Destination = "fd01::1/128";
        Gateway = "fd03::";
      }
      {
        # Route to VM2 (Database)
        Destination = "10.0.2.1/32";
        Gateway = "10.0.3.0";
      }
      {
        # IPv6 route to VM2
        Destination = "fd02::1/128";
        Gateway = "fd03::";
      }
    ];
    networkConfig = {
      DNS = ["9.9.9.9" "149.112.112.112"];
    };
  };

  # Management tools
  environment.systemPackages = with pkgs; [
    # Network tools
    inetutils
    iptables
    tcpdump
    traceroute
    nmap

    # Database client
    postgresql

    # Monitoring tools
    htop
    iotop

    # Text editors
    vim
    nano
  ];

  # Enable SSH for management
  services.openssh.enable = true;

  # Setup monitoring dashboard
  services.prometheus = {
    enable = true;
    scrapeConfigs = [
      {
        job_name = "vm_web";
        static_configs = [
          {
            targets = ["10.0.1.1:9100"];
            labels = {
              instance = "vm_web";
            };
          }
        ];
      }
      {
        job_name = "vm_database";
        static_configs = [
          {
            targets = ["10.0.2.1:9100"];
            labels = {
              instance = "vm_database";
            };
          }
        ];
      }
    ];
  };

  # Web interface for Prometheus
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
      };
      security = {
        admin_user = "admin";
        admin_password = "admin";
      };
    };
  };
}
