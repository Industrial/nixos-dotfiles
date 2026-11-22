# Mimir system configuration (file server)
{
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./filesystems.nix
    ./hardware.nix
  ];

  # profiles.ai.enable = true;
  profiles.base.enable = true;
  profiles.communication.enable = true;
  # profiles.creative.enable = true;
  profiles.desktop.enable = true;
  # Mimir is a headless-first file server; GNOME is the only desktop it needs. The desktop
  # profile turns Hyprland on fleet-wide, so opt out here rather than in the profile.
  features.window-manager.hyprland.enable = lib.mkForce false;
  profiles.development.enable = true;
  # profiles.gaming.enable = true;

  features.fleet.comin.enable = true;
  # vdeploy (Voltaic), OBSERVE mode next to comin (GH-221): plans the switch to main and
  # never makes it, and fast-forwards ~/.dotfiles (the nushell login fix). It waits for
  # main to go quiet first (deployDebounce in common/fleet.nix). comin still deploys here.
  # Rollback: lib.mkForce false.
  features.nix.vdeploy.enable = true;
  features.fleet.nix-remote-builder-client.enable = true;
  features.fleet.remote-access.enable = true;
  features.fleet.remote-desktop-relay.enable = true;
  features.monitoring.grafana.enable = true;
  features.monitoring.homepage-dashboard.enable = true;
  features.monitoring.prometheus-exporter.enable = true;
  features.monitoring.prometheus.enable = true;
  features.nixos.graphics.amd.enable = true;

  # Anduril NixOS STIG V1R3, base-safe (68 controls). Mimir is the only host that
  # carries it: it is the file server, so it is the one machine where nobody is
  # typing at the console and the audit set costs nothing anybody feels. The
  # baseline used to be in profiles/base.nix and therefore on all four hosts —
  # ADR-0004 records why it is here instead, and profiles/base.nix keeps the
  # option surface so stigReport still evaluates for the other three.
  #
  # Two controls here need a REBOOT, not just a switch: V-268092 (audit=1) and
  # V-268093 (audit_backlog_limit=65536) add kernel command line parameters, and
  # `switch-to-configuration switch` cannot change a running kernel's cmdline.
  # The report renders them "Configured (pending reboot)" until mimir restarts.
  features.security.stig.profiles.base-safe.enable = true;

  features.storage.nfs-server.enable = true;

  # features.media.jellyfin.enable = true;
  # features.media.flexget.enable = true;
  # features.media.jackett.enable = true;
  # features.media.qbittorrent-nox.enable = true;
  # features.media.transmission.enable = true;
  # features.media.seerr.enable = true;
  # features.media.invidious.enable = true;
}
