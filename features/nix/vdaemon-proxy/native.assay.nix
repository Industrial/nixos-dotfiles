# Colocated suite for features/nix/vdaemon-proxy/native.nix — vdaemon-proxy answering
# read-only ops itself (#183, phase 3): off by default, per op, only the six read-only
# ops can be named, and the kill switches' directory is there whenever an op is on.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  proxyOf = modules: (nixos.eval {modules = [./default.nix] ++ modules;}).systemd.services.vdaemon-proxy;
  off = proxyOf [];
  some = proxyOf [{features.nix.vdaemon-proxy.native = ["IsValidPath" "QueryPathInfo"];}];
  rolledBack = proxyOf [
    {features.nix.vdaemon-proxy.native = ["IsValidPath"];}
    {features.nix.vdaemon-proxy.native = lib.mkForce [];}
  ];
  # A write cannot be listed: the option's type refuses it.
  writeRefused = !(builtins.tryEval (proxyOf [{features.nix.vdaemon-proxy.native = ["AddToStore"];}]).environment.VDAEMON_NATIVE).success;
  both = proxyOf [
    {features.nix.vdaemon-proxy.native = ["QueryReferrers"];}
    {features.nix.vdaemon-proxy.conformance = true;}
  ];
in
  assay.suite "vdaemon-proxy-native" {
    # Nothing is answered natively unless asked for.
    offByDefault = assay.eq (off.environment ? VDAEMON_NATIVE) false;

    namesTheOps = assay.eq some.environment.VDAEMON_NATIVE "IsValidPath,QueryPathInfo";
    readsTheStoreDatabase = assay.eq some.environment.VDAEMON_DB "/nix/var/nix/db/db.sqlite";
    killSwitchesInTheRuntimeDirectory =
      assay.eq [some.environment.VDAEMON_SWITCH_DIR some.serviceConfig.RuntimeDirectory some.serviceConfig.RuntimeDirectoryPreserve] ["/run/vdaemon-proxy" "vdaemon-proxy" "restart"];
    # Still the read-only sandbox: the database is not writable.
    databaseNotWritable = assay.eq [some.serviceConfig.ProtectSystem some.serviceConfig.ReadWritePaths] ["strict" ["-/nix/var/nix/daemon-socket-upstream"]];

    onlyReadOnlyOps = assay.eq writeRefused true;
    withConformanceToo = assay.eq [both.environment.VDAEMON_NATIVE both.environment.VDAEMON_CONFORMANCE] ["QueryReferrers" "1"];

    # The one rollback: the list forced empty.
    rollbackForwardsEverything = assay.eq (rolledBack.environment ? VDAEMON_NATIVE) false;
  }
