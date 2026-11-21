# Colocated suite for features/nix/vverify/default.nix — the weekly store verification
# service, sandboxed, writing node_exporter textfile metrics.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  dir = "/var/lib/prometheus-node-exporter-text";
  cfg = nixos.eval {modules = [./default.nix];};
  withExporter = nixos.eval {
    modules = [
      ./default.nix
      {services.prometheus.exporters.node.enable = true;}
    ];
  };
  service = cfg.systemd.services.vverify;
  sc = service.serviceConfig;
  args = lib.splitString " " sc.ExecStart;
  argAfter = flag: let
    i = lib.lists.findFirstIndex (a: a == flag) null args;
  in
    if i == null
    then null
    else builtins.elemAt args (i + 1);
in
  assay.suite "vverify-service" {
    installsVverify = assay.eq (nixos.hasPackage cfg "vverify") true;
    runsTheInstalledBinary =
      assay.eq (builtins.match "/nix/store/[a-z0-9]+-vverify-[^/]+/bin/vverify" (builtins.head args) != null) true;
    startsAtBoot = assay.eq service.wantedBy ["multi-user.target"];

    # A daemon on vverify's own Schedule, weekly: no systemd timer drives it.
    daemonNotOnce = assay.eq (builtins.elem "--once" args) false;
    weekly = assay.eq (argAfter "--interval") "1w";
    noTimer = assay.eq (cfg.systemd.timers ? vverify) false;
    readsTheStoreDatabase = assay.eq (argAfter "--db") "/nix/var/nix/db/db.sqlite";
    writesTheTextfileDir = assay.eq [(argAfter "--textfile-dir") (argAfter "--report")] [dir "${dir}/vverify.json"];
    restartsOnFailure = assay.eq sc.Restart "on-failure";

    # Low priority: CPU and disk only when nothing else wants them.
    lowPriority = assay.eq [sc.Nice sc.IOSchedulingClass sc.CPUSchedulingPolicy] [19 "idle" "batch"];

    # Sandbox: the store and database read-only, the textfile dir the only writable path.
    dynamicUser = assay.eq sc.DynamicUser true;
    protectSystemStrict = assay.eq sc.ProtectSystem "strict";
    readsStoreAndDbReadOnly = assay.eq sc.ReadOnlyPaths ["/nix/store" "/nix/var/nix/db"];
    onlyWritesTheTextfileDir = assay.eq sc.ReadWritePaths [dir];
    noStateDirectory = assay.eq [(sc ? StateDirectory) (sc ? CacheDirectory) (sc ? LogsDirectory)] [false false false];
    writesThroughTheTextfileGroup = assay.eq sc.SupplementaryGroups ["prometheus-textfile"];
    filesReadableByTheExporter = assay.eq sc.UMask "0022";
    noDaemonSocket = assay.eq sc.InaccessiblePaths ["-/nix/var/nix/daemon-socket"];
    noNetwork = assay.eq [sc.PrivateNetwork sc.RestrictAddressFamilies] [true ["AF_UNIX"]];
    noCapabilities = assay.eq [sc.CapabilityBoundingSet sc.AmbientCapabilities sc.NoNewPrivileges] [[""] [""] true];
    hardened = assay.subset sc {
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictNamespaces = true;
      RestrictSUIDSGID = true;
      MemoryDenyWriteExecute = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
    };

    # The textfile directory: created at boot, setgid to the writers' group.
    textfileDirCreated = assay.eq (builtins.elem "d ${dir} 2775 root prometheus-textfile - -" cfg.systemd.tmpfiles.rules) true;
    textfileGroupExists = assay.eq (cfg.users.groups ? prometheus-textfile) true;

    # node_exporter reads it, but only where the exporter runs at all.
    exporterReadsTheDir =
      assay.eq (builtins.elem "--collector.textfile.directory=${dir}" withExporter.services.prometheus.exporters.node.extraFlags) true;
    noExporterNoFlag = assay.eq cfg.services.prometheus.exporters.node.extraFlags [];
    textfileCollectorNotDisabled =
      assay.eq (builtins.elem "textfile" withExporter.services.prometheus.exporters.node.disabledCollectors) false;
  }
