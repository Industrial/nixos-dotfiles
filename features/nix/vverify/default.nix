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
# node_exporter: the fleet's exporter (features/monitoring/prometheus-exporter) has no
# textfile collector directory configured, so this feature adds one: the directory below,
# created by tmpfiles (root:prometheus-textfile, setgid, 2775), and
# `--collector.textfile.directory` on the exporter. The textfile collector itself is one of
# node_exporter's defaults; it only needs the directory. Kept here rather than in the
# exporter feature so a host without vverify sees no change at all; another writer joins
# the group.
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
  config,
  lib,
  pkgs,
  ...
}: let
  vverify = pkgs.callPackage ../../../rust/tools/vverify/default.nix {};
  textfileDir = "/var/lib/prometheus-node-exporter-text";
  group = "prometheus-textfile";
in {
  environment.systemPackages = [vverify];

  users.groups.${group} = {};

  systemd.tmpfiles.rules = ["d ${textfileDir} 2775 root ${group} - -"];

  services.prometheus.exporters.node.extraFlags =
    lib.mkIf config.services.prometheus.exporters.node.enable
    ["--collector.textfile.directory=${textfileDir}"];

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
