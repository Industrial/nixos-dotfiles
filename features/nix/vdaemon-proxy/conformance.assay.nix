# Colocated suite for features/nix/vdaemon-proxy/conformance.nix — the proxy's
# conformance mode (#183): off unless asked for, and when on, the proxy reads the store
# database read-only and writes its counters where any user can read them.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  proxyOf = modules: (nixos.eval {modules = [./default.nix] ++ modules;}).systemd.services.vdaemon-proxy;
  off = proxyOf [];
  on = proxyOf [{features.nix.vdaemon-proxy.conformance = true;}];
  rolledBack = proxyOf [
    {features.nix.vdaemon-proxy.conformance = true;}
    {features.nix.vdaemon-proxy.conformance = lib.mkForce false;}
  ];
  hasConformance = svc: svc.environment ? VDAEMON_CONFORMANCE;
in
  assay.suite "vdaemon-proxy-conformance" {
    # Off by default: the proxy only relays.
    offByDefault = assay.eq (hasConformance off) false;
    noRuntimeDirectoryWhenOff = assay.eq (off.serviceConfig ? RuntimeDirectory) false;

    switchedOn = assay.eq on.environment.VDAEMON_CONFORMANCE "1";
    readsTheStoreDatabase = assay.eq on.environment.VDAEMON_DB "/nix/var/nix/db/db.sqlite";
    countersInTheRuntimeDirectory = assay.eq on.environment.VDAEMON_METRICS "/run/vdaemon-proxy/conformance.prom";
    # Any user can read the counters (the probe needs no root).
    countersReadableByUsers = assay.eq [on.serviceConfig.RuntimeDirectory on.serviceConfig.RuntimeDirectoryMode on.serviceConfig.UMask] ["vdaemon-proxy" "0755" "0022"];
    # The database stays read-only to the proxy: the sandbox is unchanged.
    databaseNotWritable = assay.eq [on.serviceConfig.ProtectSystem on.serviceConfig.ReadWritePaths] ["strict" ["-/nix/var/nix/daemon-socket-upstream"]];
    stillRelays = assay.eq on.environment.VDAEMON_UPSTREAM "/nix/var/nix/daemon-socket-upstream/socket";

    # The one rollback: the option forced off.
    rollbackRestoresRelayOnly = assay.eq (hasConformance rolledBack) false;
  }
