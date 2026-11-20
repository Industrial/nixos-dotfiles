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
    # No cron. Store GC is nix.gc in features/nixos/default.nix, which keeps a
    # rollback window (the old nightly `nix-collect-garbage -d` deleted every
    # generation). Store dedup is nix.settings.auto-optimise-store, and the
    # journal is capped by journald's SystemMaxUse. STIG V-268097 audits
    # /var/cron/tabs, which that control provisions itself via tmpfiles, so its
    # watch loads whether or not a cron daemon runs.

    # Optimize timesyncd
    timesyncd = {
      enable = true;
    };
  };
}
