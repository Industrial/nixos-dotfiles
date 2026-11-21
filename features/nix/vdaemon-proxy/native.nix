# vdaemon-proxy answering read-only ops itself (#183, phase 3), per op, off by default.
#
#   features.nix.vdaemon-proxy.native = ["IsValidPath" "QueryPathInfo" ...];
#
# An op in the list is answered by the proxy from the store database (read-only) and
# the store, with nix-store-core, instead of by nix-daemon: no round trip to the daemon,
# and no daemon process for it. Only the six read-only ops can be listed
# (IsValidPath, QueryValidPaths, QueryPathInfo, QueryPathFromHashPart, QueryReferrers,
# NarFromPath); every write and every build is always forwarded, and so is any
# request the proxy is not certain to answer exactly as the daemon would (see
# rust/tools/vdaemon-proxy/src/answer.vlt). Turn an op on only after conformance mode
# (./conformance.nix) has shown it equal to the daemon's.
#
# Kill switch, instant, no restart and no dropped connection (root, on the host):
#   touch /run/vdaemon-proxy/forward-all             every op forwarded again
#   touch /run/vdaemon-proxy/forward-QueryPathInfo   one op forwarded again
#   rm    /run/vdaemon-proxy/forward-…               back to native
#
# Rollback: `features.nix.vdaemon-proxy.native = lib.mkForce [];`.
#
# Probe, as a user: the journal's op lines carry "answered":"native" or "daemon".
#   journalctl -u vdaemon-proxy --since -1min -o cat | grep -c '"answered":"native"'
{
  config,
  lib,
  ...
}: let
  cfg = config.features.nix.vdaemon-proxy;
  readOnlyOps = ["IsValidPath" "QueryValidPaths" "QueryPathInfo" "QueryPathFromHashPart" "QueryReferrers" "NarFromPath"];
in {
  options.features.nix.vdaemon-proxy.native = lib.mkOption {
    type = lib.types.listOf (lib.types.enum readOnlyOps);
    default = [];
    example = ["IsValidPath" "QueryPathInfo"];
    description = "Read-only daemon ops vdaemon-proxy answers itself instead of forwarding. Kill switch: touch /run/vdaemon-proxy/forward-all (or forward-<Op>).";
  };

  config = lib.mkIf (cfg.native != []) {
    systemd.services.vdaemon-proxy = {
      environment = {
        VDAEMON_NATIVE = lib.concatStringsSep "," cfg.native;
        VDAEMON_DB = "/nix/var/nix/db/db.sqlite";
        VDAEMON_SWITCH_DIR = "/run/vdaemon-proxy";
      };
      serviceConfig = {
        RuntimeDirectory = "vdaemon-proxy";
        RuntimeDirectoryMode = "0755";
        # The kill switches outlive a restart of the proxy.
        RuntimeDirectoryPreserve = "restart";
      };
    };
  };
}
