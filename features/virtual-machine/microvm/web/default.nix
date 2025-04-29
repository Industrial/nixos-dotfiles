{
  settings,
  ...
}: {
  # vm_web - Web Server Configuration
  microvm = {
    interfaces = [
      {
        type = "tap";
        id = "vm_web";
        mac = "02:00:00:01:00:01";
      }
    ];
  };

  # Network configuration
  networking = {
    useNetworkd = true;
    hostName = settings.hostname;
    firewall = {
      enable = true;
      # Web and SSH
      allowedTCPPorts = [80 443 22];
    };
  };

  # Static IP configuration
  systemd = {
    network = {
      networks = {
        "10-eth" = {
          matchConfig = {
            MACAddress = "02:00:00:01:00:01";
          };
          address = [
            "10.0.0.1/32"
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

  # Web server configuration
  services = {
    nginx = {
      enable = true;
      virtualHosts = {
        "${settings.hostname}" = {
          root = "/var/www/html";
        };
      };
    };
  };

  # Create a basic web page
  system = {
    activationScripts = {
      createWebRoot = ''
        mkdir -p /var/www/html
        echo "<html><body><h1>vm_web Web Server</h1><p>This is the web server VM in our routed network setup.</p></body></html>" > /var/www/html/index.html
      '';
    };
  };
}
