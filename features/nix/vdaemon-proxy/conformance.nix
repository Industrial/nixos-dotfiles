# vdaemon-proxy's conformance mode (#183), off by default.
#
# Every read-only op (IsValidPath, QueryValidPaths, QueryPathInfo, QueryPathFromHashPart,
# QueryReferrers, NarFromPath) is still forwarded to nix-daemon, and the client always
# gets nix-daemon's answer. Alongside, the proxy computes its own answer from the store
# database and the store (nix-store-core), compares it byte for byte, and logs and
# counts every difference. This is the evidence gate before any op is answered natively.
#
# What it adds to the proxy's service:
#
#   VDAEMON_CONFORMANCE=1, VDAEMON_DB   the database, read-only. Nothing is written:
#                                       ProtectSystem=strict keeps /nix/var/nix/db a
#                                       read-only mount, and SQLite reads a WAL database
#                                       through its existing -shm without write access.
#   VDAEMON_METRICS                     the counters as a Prometheus textfile, written
#                                       every 30 s, every 1000 verdicts and at each
#                                       difference, in /run/vdaemon-proxy (0755, so any
#                                       user can read it).
#
# Probe, as a user (no root needed):
#   grep '^vdaemon_conformance_diffs_total ' /run/vdaemon-proxy/conformance.prom
#   journalctl -u vdaemon-proxy -o cat | grep -F '"event":"conformance_diff"'
#
# Rollback: drop `features.nix.vdaemon-proxy.conformance = true;` (or mkForce false);
# the proxy goes back to relaying only.
{
  config,
  lib,
  ...
}: let
  cfg = config.features.nix.vdaemon-proxy;
  runtime = "vdaemon-proxy";
in {
  options.features.nix.vdaemon-proxy.conformance = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Compare the proxy's native answers to read-only ops with nix-daemon's (which clients still get), counting every difference in /run/vdaemon-proxy/conformance.prom.";
  };

  config = lib.mkIf cfg.conformance {
    systemd.services.vdaemon-proxy = {
      environment = {
        VDAEMON_CONFORMANCE = "1";
        VDAEMON_DB = "/nix/var/nix/db/db.sqlite";
        VDAEMON_METRICS = "/run/${runtime}/conformance.prom";
      };
      serviceConfig = {
        RuntimeDirectory = runtime;
        RuntimeDirectoryMode = "0755";
        # Kept across the proxy's restarts, so the counters' file does not vanish
        # between a crash and the restart (the counts themselves start again at 0).
        RuntimeDirectoryPreserve = "restart";
        UMask = "0022";
      };
    };
  };
}
