# Colocated suite for features/nix/vcache/default.nix — vcache serving the local store to
# the fleet, sandboxed, on the tailnet only.
#
# Evaluated as drakkar (a builder with a tailnet address), so the listener claims read the
# address common/fleet.nix holds for it rather than a literal.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  fleet = import ../../../common/fleet.nix;

  serving = "drakkar";
  cfg = nixos.eval {
    modules = [./default.nix];
    settings.hostname = serving;
  };
  service = cfg.systemd.services.vcache;
  sc = service.serviceConfig;
  env = service.environment;

  failedAssertions = c: map (a: a.message) (lib.filter (a: !a.assertion) c.assertions);
  # A builder without a tailnet address (muninn), and a non-builder (mimir).
  noAddress = lib.findFirst (n: !(fleet.hosts.${n} ? tailscaleIp)) null (fleet.withRole "builder");
  notBuilder = lib.findFirst (n: !(fleet.hasRole "builder" n)) null fleet.order;
  assertionsAs = hostname:
    failedAssertions (nixos.eval {
      modules = [./default.nix];
      settings.hostname = hostname;
    });
in
  assay.suite "vcache-server" {
    installsVcache = assay.eq (nixos.hasPackage cfg "vcache") true;
    runsTheInstalledBinary =
      assay.eq (builtins.match "/nix/store/[a-z0-9]+-vcache-[^/]+/bin/vcache" sc.ExecStart != null) true;
    startsAtBoot = assay.eq service.wantedBy ["multi-user.target"];
    waitsForTheTailnet = assay.eq (builtins.elem "tailscaled.service" service.after) true;

    # Supervised: back after any exit, and never parked by a start limit.
    restartsAlways = assay.eq [sc.Restart sc.RestartSec] ["always" "5s"];
    neverHitsAStartLimit = assay.eq service.startLimitIntervalSec 0;

    # Tailnet only: the host's fleet.nix address, the fleet port, and only tailscale0 open.
    bindsTheTailnetAddress = assay.eq env.HOST fleet.hosts.${serving}.tailscaleIp;
    listensOnTheFleetPort = assay.eq env.PORT (toString fleet.cachePort);
    opensOnlyTailscale0 = assay.eq [
      cfg.networking.firewall.interfaces.tailscale0.allowedTCPPorts
      (builtins.elem fleet.cachePort cfg.networking.firewall.allowedTCPPorts)
    ] [[fleet.cachePort] false];

    # Sandbox.
    dynamicUser = assay.eq sc.DynamicUser true;
    protectSystemStrict = assay.eq sc.ProtectSystem "strict";
    readsStoreAndDbReadOnly = assay.eq sc.ReadOnlyPaths ["/nix/store" "/nix/var/nix/db"];
    noDaemonSocket = assay.eq sc.InaccessiblePaths ["-/nix/var/nix/daemon-socket"];
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
    onlyIpAndUnixSockets = assay.eq sc.RestrictAddressFamilies ["AF_INET" "AF_INET6" "AF_UNIX"];
    readsTheLocalStore = assay.eq [env.VCACHE_STORE_DIR env.VCACHE_DB] ["/nix/store" "/nix/var/nix/db/db.sqlite"];

    # The key: generated into the private StateDirectory at start, never in the store.
    keyInStateDirectory = assay.eq [sc.StateDirectory sc.StateDirectoryMode env.VCACHE_SIGN_KEY_FILE] ["vcache" "0700" "/var/lib/vcache/secret-key"];
    keyNotInStore = assay.eq (lib.hasPrefix "/nix/store" env.VCACHE_SIGN_KEY_FILE) false;
    generatesKeyBeforeServing = assay.eq (lib.hasInfix "vcache-ensure-key" (toString sc.ExecStartPre)) true;

    # Serving hosts are builders with a tailnet address; anything else fails evaluation.
    servingHostPassesAssertions = assay.eq (failedAssertions cfg) [];
    builderWithoutAddressRefused = assay.eq (builtins.length (assertionsAs noAddress)) 1;
    nonBuilderRefused = assay.eq (builtins.length (assertionsAs notBuilder) >= 1) true;

    # GH-248: the request counters go straight to node_exporter's textfile directory, as
    # the group's member, with only that directory writable; the sandbox is unchanged.
    countersInTheTextfileDir = assay.eq [env.VCACHE_TEXTFILE_DIR sc.SupplementaryGroups sc.ReadWritePaths] ["/var/lib/prometheus-node-exporter-text" ["prometheus-textfile"] ["/var/lib/prometheus-node-exporter-text"]];
    noCopierUnit = assay.eq (cfg.systemd.services ? vcache-metrics) false;
    sandboxKept = assay.eq [sc.PrivateUsers sc.UMask sc.DynamicUser] [true "0077" true];
  }
