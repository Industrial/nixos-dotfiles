{
  config,
  lib,
  pkgs,
  ...
}: {
  # Comprehensive systemd configuration with security and performance optimizations

  systemd = {
    oomd = {
      enable = true;
    };

    # dbus-broker reload (Type=notify-reload) exceeds DefaultTimeoutStartSec on
    # large desktop configs and fails switch-to-configuration with exit 4.
    # Do not restart on switch — it cascades into display-manager and kills the
    # active graphical session.
    services.dbus-broker = {
      reloadIfChanged = lib.mkForce false;
      restartIfChanged = lib.mkForce false;
      serviceConfig.TimeoutStartSec = lib.mkForce "5min";
    };

    services.display-manager = {
      restartIfChanged = lib.mkForce false;
    };

    user.services.dbus-broker = {
      reloadIfChanged = lib.mkForce false;
      restartIfChanged = lib.mkForce false;
      serviceConfig.TimeoutStartSec = lib.mkForce "5min";
    };

    # Security-focused systemd configuration
    settings = {
      Manager = {
        # dbus-broker restart can exceed 30s on large desktop configs.
        DefaultTimeoutStartSec = "90s";
        DefaultTimeoutStopSec = "30s";
        DefaultRestartSec = "100ms";
      };
    };
  };

  # Configure services for performance and security
  services = {
    # Optimize cron for performance
    cron = {
      enable = true;
      systemCronJobs = [
        # Optimize system performance
        "0 2 * * * root /run/current-system/sw/bin/nix-collect-garbage -d"
        "0 3 * * * root /run/current-system/sw/bin/nix-store --optimise"
        "30 3 * * 0 root /run/current-system/sw/bin/journalctl --vacuum-size=800M"
      ];
    };

    # Optimize timesyncd
    timesyncd = {
      enable = true;
    };
  };
}
