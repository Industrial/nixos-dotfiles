{
  settings,
  pkgs,
  ...
}: {
  virtualisation = {
    docker = {
      enable = true;
      # Enable Docker daemon on boot
      enableOnBoot = true;

      rootless = {
        enable = true;
        setSocketVariable = true;

        extraPackages = with pkgs; [
          docker-buildx # buildkit builder management
          docker-compose # compose v2 plugin (if you use `docker compose`, not standalone binary)
        ];

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

    # Rootless dockerd (Go TLS) does not pick up system CAs without this;
    # otherwise pulls fail with: x509: certificate signed by unknown authority
    user.services.docker.serviceConfig.Environment = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
  };

  boot = {
    kernel = {
      sysctl = {
        "net.ipv4.ip_unprivileged_port_start" = 80;
      };
    };
  };
}
