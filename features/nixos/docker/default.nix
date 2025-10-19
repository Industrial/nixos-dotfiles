{settings, ...}: {
  virtualisation = {
    docker = {
      enable = true;
      # Enable Docker daemon on boot
      enableOnBoot = true;
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
}
