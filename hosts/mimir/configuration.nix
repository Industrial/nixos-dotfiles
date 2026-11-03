# Mimir system configuration (file server)
{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./filesystems.nix
    ./hardware.nix

    # ../../profiles/ai.nix
    ../../profiles/base.nix
    ../../profiles/communication.nix
    #../../profiles/creative.nix
    ../../profiles/desktop.nix
    ../../profiles/development.nix
    #../../profiles/gaming.nix

    ../../features/fleet/comin.nix
    ../../features/fleet/nix-remote-builder-client.nix
    ../../features/fleet/remote-access.nix
    ../../features/fleet/remote-desktop-relay.nix
    ../../features/monitoring/grafana/default.nix
    ../../features/monitoring/homepage-dashboard
    ../../features/monitoring/prometheus-exporter/default.nix
    ../../features/monitoring/prometheus/default.nix
    ../../features/nixos/graphics/amd.nix

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
    ../../features/security/stig/profiles/base-safe.nix

    ../../features/storage/nfs-server

    # ../../features/media/jellyfin/default.nix
    # ../../features/media/flexget/default.nix
    # ../../features/media/jackett/default.nix
    # ../../features/media/qbittorrent-nox/default.nix
    # ../../features/media/transmission/default.nix
    # ../../features/media/seerr/default.nix
    # ../../features/media/invidious/default.nix
  ];
}
