{settings, ...}: {
  virtualisation = {
    docker = {
      enable = true;
      # Enable Docker daemon on boot
      enableOnBoot = true;

      rootless = {
        enable = true;
        setSocketVariable = true;
        # Optionally customize rootless Docker daemon settings
        daemon.settings = {
          dns = ["1.1.1.1" "8.8.8.8"];
          registry-mirrors = ["https://mirror.gcr.io"];
        };
      };
    };
  };

  # Add user to docker group for running Docker commands
  users = {
    groups = {
      docker = {};
    };
    users = {
      "${settings.username}" = {
        extraGroups = ["docker"];
      };
    };
  };

  # Ensure Docker socket has proper permissions
  systemd = {
    services = {
      docker = {
        serviceConfig = {
          # Ensure docker group has access to socket
          SupplementaryGroups = ["docker"];
        };
      };
    };
  };

  boot = {
    kernel = {
      sysctl = {
        "net.ipv4.ip_unprivileged_port_start" = 80;
      };
    };
  };
}
