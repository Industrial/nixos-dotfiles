# vexporter (rust/tools/vexporter, GH-248): the Nix and fleet metrics no other tool owns,
# as node_exporter's textfile vexporter.prom, every minute. Each tool keeps writing its own
# file (vci, vdeploy, vhealth, vverify); vexporter adds:
#
#   the store         vexporter_store_paths, vexporter_store_nar_bytes (one read-only
#                     query on the database per run, no transaction held: 27 ms on
#                     drakkar's 188,755 paths), vexporter_nix_fs_{size,free}_bytes
#   GC roots          vexporter_gcroots, vexporter_gcroots_unreadable (links never
#                     followed out of /nix/var/nix/gcroots)
#   generations       vexporter_generations, vexporter_generation_{newest,oldest}_age_seconds,
#                     vexporter_reboot_pending, vexporter_profile_is_running
#   the deploy lag    vexporter_on_main, vexporter_deploy_lag_seconds (from vdeploy's
#                     status.json and plan.json, against the running configurationRevision)
#   itself            vexporter_source_up{source}: a source that fails is 0 and leaves only
#                     its own gauges out, never the whole file
#
# Runs as its own static user `vexporter` in the prometheus-textfile group, read-only
# everywhere except the textfile directory, with no access to the Nix daemon (it reads the
# database file, as vdiff does). The file is written atomically (temp file, then rename).
#
# Rollback: `features.monitoring.vexporter.enable = lib.mkForce false;`.
#
# Probe (no root): grep -E '^vexporter_(source_up|on_main|store_paths)' \
#   /var/lib/prometheus-node-exporter-text/vexporter.prom
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.features.monitoring.vexporter;
  vexporter = pkgs.callPackage ../../../rust/tools/vexporter/default.nix {};
  textfileDir = "/var/lib/prometheus-node-exporter-text";
in {
  imports = [../textfile-collector.nix];

  options.features.monitoring.vexporter.interval = lib.mkOption {
    type = lib.types.strMatching "[0-9]+[smh]?";
    default = "1m";
    description = "How often the file is written.";
  };

  config = {
    environment.systemPackages = [vexporter];

    # The vexporter account and group are Voltaic's (#457): rust/tools/nixos-users.
    users = (import ../../nixos/users/voltaic.nix).fragments.vexporter;

    systemd.services.vexporter = {
      description = "vexporter: the store, the generations and the deploy lag, into node_exporter";
      wantedBy = ["multi-user.target"];
      after = ["systemd-tmpfiles-setup.service"];
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.escapeShellArgs [
          "${vexporter}/bin/vexporter"
          "--textfile-dir"
          textfileDir
          "--interval"
          cfg.interval
          "--nixos-version"
          "/run/current-system/sw/bin/nixos-version"
        ];
        Restart = "always";
        RestartSec = "30s";
        User = "vexporter";
        Group = "vexporter";
        SupplementaryGroups = ["prometheus-textfile"];
        UMask = "0022";
        Nice = 10;
        ProtectSystem = "strict";
        ReadWritePaths = [textfileDir];
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        PrivateNetwork = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        CapabilityBoundingSet = "";
      };
    };
  };
}
