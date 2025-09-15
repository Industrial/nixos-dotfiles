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

    # Security-focused systemd configuration
    settings = {
      Manager = {
        # Security settings
        DefaultTimeoutStartSec = "30s";
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
      ];
    };

    # Optimize timesyncd
    timesyncd = {
      enable = true;
    };
  };
}
