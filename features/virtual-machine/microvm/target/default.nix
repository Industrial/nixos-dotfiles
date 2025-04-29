{
  settings,
  pkgs,
  ...
}: {
  # vm_target - Target VM Configuration
  microvm = {
    interfaces = [
      {
        type = "tap";
        id = "vm_target";
        mac = "02:00:00:01:00:03";
      }
    ];
  };

  # Network configuration
  networking = {
    useNetworkd = true;
    hostName = settings.hostname;
    firewall = {
      enable = true;
      allowedTCPPorts = [22]; # Allow SSH
    };
  };

  # Static IP configuration
  systemd = {
    network = {
      networks = {
        "10-eth" = {
          matchConfig = {
            MACAddress = "02:00:00:01:00:03"; # Match the MAC address of vm_target
          };
          address = [
            "10.0.0.3/32" # New IP address
          ];
          routes = [
            # {
            #   Destination = "10.0.0.0/32"; # Route to host
            #   GatewayOnLink = true;
            # }
            {
              Destination = "10.0.0.2/32"; # Route to vm_tor
              GatewayOnLink = true;
            }
            {
              Destination = "0.0.0.0/0";
              Gateway = "10.0.0.2"; # Default gateway is vm_tor
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

  systemd = {
    services = {
      target-web-fetch = {
        description = "Fetch a webpage and log the result";
        after = ["network.target"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          ExecStart = "${pkgs.nodejs}/bin/node -e 'const https = require(\"https\"); https.get(\"https://check.torproject.org/\", (res) => { let data = \"\"; res.on(\"data\", (chunk) => data += chunk); res.on(\"end\", () => require(\"fs\").writeFileSync(\"/tmp/webfetch.log\", data)); })'";
          Restart = "on-failure";
        };
      };
    };
  };
  environment = {
    systemPackages = with pkgs; [
      nodejs
    ];
  };
}
