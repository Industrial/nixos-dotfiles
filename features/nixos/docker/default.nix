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
          # Mullvad VPN's DNS leak protection silently drops port-53 traffic from
          # the docker bridge to any resolver other than its own (10.64.0.1), so
          # public DNS (1.1.1.1 / 8.8.8.8) times out from inside containers and
          # `apt-get update` fails to resolve deb.debian.org. Using Mullvad's DNS
          # works while the VPN is up (Lockdown Mode kills container egress when
          # it's down anyway, so no point in a public-DNS fallback).
          dns = ["10.64.0.1"];
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
