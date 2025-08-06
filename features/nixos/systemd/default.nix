{
  config,
  lib,
  pkgs,
  ...
}: {
  # Comprehensive systemd configuration with security and performance optimizations

  systemd = {
    # Optimize systemd settings for both security and performance
    extraConfig = ''
      DefaultTimeoutStartSec=30s
      DefaultTimeoutStopSec=30s
      DefaultRestartSec=100ms
      DefaultLimitCORE=0
      DefaultLimitNOFILE=1048576
      DefaultLimitNPROC=1048576
    '';

    # Configure services for security and performance
    services = {
      # Configure systemd-oomd for memory management
      "systemd-oomd" = {
        enable = true;
      };

      # Configure systemd-resolved for DNS resolution
      "systemd-resolved" = {
        enable = true;
      };

      # Configure systemd-timesyncd for time synchronization
      "systemd-timesyncd" = {
        enable = true;
      };
    };

    # Configure user services
    user.services = {
      # Optimize user services
    };
  };

  # Configure services for performance and security
  services = {
    # Optimize systemd services
    systemd-oomd = {
      enable = true;
    };

    # Optimize logging
    journald = {
      enable = true;
      extraConfig = ''
        SystemMaxUse=1G
        SystemMaxFileSize=100M
        MaxRetentionSec=1month
      '';
    };

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

    # Optimize resolved
    resolved = {
      enable = true;
      extraConfig = ''
        DNS=1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4
        FallbackDNS=1.1.1.1 1.0.0.1
        DNSSEC=yes
        DNSOverTLS=yes
        MulticastDNS=yes
        LLMNR=yes
      '';
    };
  };
}
