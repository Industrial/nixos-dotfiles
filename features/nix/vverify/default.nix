# vverify (rust/tools/vverify): the store's content checked against its database, every
# week, reported to node_exporter. Each pass archives every valid path, hashes the NAR and
# compares it with the narHash and narSize Nix registered: the content half of
# `nix store verify --all`, in parallel and without the daemon.
#
# Schedule: the service is a daemon and the repetition is vverify's own (an id_effect
# Schedule, `--interval`, a week), not a systemd timer. The first pass after a start waits
# out the rest of the interval since the last recorded pass, read back from the metrics
# file, so a deploy or a reboot does not trigger a full pass.
#
# Load: `--jobs` defaults to half the CPUs; the unit runs at Nice 19 with the idle I/O
# class, so a pass only takes disk time nothing else wants.
#
# Sandbox: a DynamicUser with ProtectSystem=strict and no network. It reads /nix/store and
# the database (opened read-only, as vcache does), never the daemon socket. Its only
# writable path is the textfile directory, through the `prometheus-textfile` group.
#
# node_exporter: the textfile collector directory (created by tmpfiles, setgid to the
# prometheus-textfile group, and passed to the exporter) is
# features/monitoring/textfile-collector.nix, imported here and by features/nix/vhealth,
# so a host without either sees no change at all.
#
# vhealth: the metrics file's freshness is a probe (`vverify-metrics`), not critical: a
# first pass after a fresh install takes long, and a stale file is not something a
# rollback fixes.
#
# Output: `vverify.prom` (vverify_paths_total, vverify_paths_corrupt, vverify_paths_missing,
# vverify_paths_unreadable, vverify_last_run_timestamp_seconds, vverify_duration_seconds)
# and `vverify.json` (every corrupt, missing or unreadable path) in the textfile directory,
# each replaced atomically; the JSON also goes to the journal, once per pass.
#
# Health probe (run on the host; a first pass can take long, so an active unit with no
# metrics file yet is a pass in progress):
#   systemctl is-active vverify \
#     && { grep -q '^vverify_paths_total ' /var/lib/prometheus-node-exporter-text/vverify.prom \
#          || echo "first pass in progress"; }
{
  lib,
  pkgs,
  ...
}: let
  vverify = pkgs.callPackage ../../../rust/tools/vverify/default.nix {};
  textfileDir = "/var/lib/prometheus-node-exporter-text";
  group = "prometheus-textfile";
  # Eight days: the weekly pass plus a day's slack.
  maxAge = 8 * 24 * 3600;
in {
  imports = [
    ../../../common/vhealth-probes.nix
    ../../monitoring/textfile-collector.nix
  ];

  environment.systemPackages = [vverify];

  features.nix.vhealth.probes.vverify-metrics = {
    type = "file";
    path = "${textfileDir}/vverify.prom";
    inherit maxAge;
    critical = false;
    description = "vverify's textfile metrics are at most eight days old";
  };

  systemd.services.vverify = {
    description = "vverify: the Nix store verified against its database, weekly";
    wantedBy = ["multi-user.target"];
    after = ["local-fs.target" "systemd-tmpfiles-setup.service"];

    serviceConfig = {
      Type = "simple";
      ExecStart = lib.escapeShellArgs [
        "${vverify}/bin/vverify"
        "--interval"
        "1w"
        "--db"
        "/nix/var/nix/db/db.sqlite"
        "--textfile-dir"
        textfileDir
        "--report"
        "${textfileDir}/vverify.json"
      ];
      # A crash restarts; a clean stop (a deploy) does not need to.
      Restart = "on-failure";
      RestartSec = "1min";

      Nice = 19;
      IOSchedulingClass = "idle";
      CPUSchedulingPolicy = "batch";

      DynamicUser = true;
      SupplementaryGroups = [group];
      # node_exporter (its own user) reads what is written: 0644 files.
      UMask = "0022";

      ProtectSystem = "strict";
      ReadOnlyPaths = ["/nix/store" "/nix/var/nix/db"];
      ReadWritePaths = [textfileDir];
      InaccessiblePaths = ["-/nix/var/nix/daemon-socket"];
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateNetwork = true;
      # Not PrivateUsers: in its user namespace the prometheus-textfile group would be
      # unmapped, and that group is the one write the unit has.
      ProtectProc = "invisible";
      ProcSubset = "pid";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      NoNewPrivileges = true;
      CapabilityBoundingSet = [""];
      AmbientCapabilities = [""];
      RestrictAddressFamilies = ["AF_UNIX"];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = ["@system-service" "~@privileged" "~@resources"];
      SystemCallErrorNumber = "EPERM";
    };
  };
}
