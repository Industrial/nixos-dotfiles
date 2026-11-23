# Colocated suite for features/nix/vci/default.nix — the fleet CI service on the cache
# host: what it builds, as whom, how it is sandboxed, and that statuses are off by default.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  fleet = import ../../../common/fleet.nix;

  plain = nixos.eval {modules = [./default.nix];};
  svc = plain.systemd.services.vci;
  exec = svc.serviceConfig.ExecStart;
  has = s: lib.hasInfix s exec;

  # Statuses turned on with a token file, on a host whose daemon is restricted.
  withToken = nixos.eval {
    modules = [
      ./default.nix
      {
        features.nix.vci.statusTokenFile = "/var/lib/secrets/vci-status-token";
        features.nix.vci.restrictedNixUsers = true;
        nix.settings.allowed-users = ["@wheel"];
      }
    ];
  };
  tokened = withToken.systemd.services.vci;

  # GH-287: on each cache host (common/fleet.nix `isCacheIn`, never named here), vci is told
  # its own name, so that host's entry is evaluated and built first.
  caches = lib.filter (fleet.isCacheIn fleet.hosts) fleet.order;
  asHost = name: nixos.eval {modules = [./default.nix {networking.hostName = name;}];};
  execOf = c: c.systemd.services.vci.serviceConfig.ExecStart;
  notOwn = nixos.eval {modules = [./default.nix {features.nix.vci.ownHost = null;}];};
in
  assay.suite "nix-vci" {
    # Every fleet host, read from common/fleet.nix, never named here.
    buildsEveryFleetHost = assay.eq plain.features.nix.vci.hosts fleet.order;
    passesEachHost = assay.eq (map (h: has "--host ${h}") fleet.order) (map (_: true) fleet.order);
    # Its own host first (GH-287): the name comes from the host, the order from fleet.nix.
    aCacheHostToCheck = assay.eq (caches != []) true;
    ownHostIsTheHostName = assay.eq (map (n: (asHost n).features.nix.vci.ownHost) caches) caches;
    ownHostPassed = assay.eq (map (n: lib.hasInfix "--own-host ${n}" (execOf (asHost n))) caches) (map (_: true) caches);
    hostsStayInFleetOrder = assay.eq (map (n: (asHost n).features.nix.vci.hosts) caches) (map (_: fleet.order) caches);
    ownHostOff = assay.eq (lib.hasInfix "--own-host" (execOf notOwn)) false;
    thisRepositoryMainAndPrs = assay.eq [(has "--url https://github.com/Industrial/nixos-dotfiles.git") (has "--repo-slug Industrial/nixos-dotfiles") (has "--no-pulls")] [true true false];
    absoluteTools = assay.eq (map (f: has "${f} /nix/store/") ["--git" "--curl" "--nix"]) [true true true];
    metricsToNodeExporter = assay.eq (has "--textfile-dir /var/lib/prometheus-node-exporter-text") true;

    # Off by default: no token anywhere, no credential, no status flag.
    statusesOffByDefault = assay.eq [plain.features.nix.vci.statusTokenFile (has "--status-token-file") (svc.serviceConfig ? LoadCredential)] [null false false];
    # On: the root-only file reaches the unit as a credential, never argv or environment.
    tokenAsCredential = assay.eq tokened.serviceConfig.LoadCredential ["status-token:/var/lib/secrets/vci-status-token"];
    tokenPathOnlyByCredentialDir = assay.eq [(lib.hasInfix "--status-token-file %d/status-token" tokened.serviceConfig.ExecStart) (lib.hasInfix "vci-status-token" tokened.serviceConfig.ExecStart)] [true false];
    tokenNotInEnvironment = assay.eq (lib.any (v: lib.hasInfix "token" (toString v)) (lib.attrValues tokened.environment)) false;

    # Its own unprivileged user, allowed the daemon (never trusted), where it is restricted.
    ownUser = assay.eq [svc.serviceConfig.User plain.users.users.vci.isSystemUser] ["vci" true];
    neverTrusted = assay.eq (builtins.elem "vci" (withToken.nix.settings.trusted-users or [])) false;
    allowedOnRestrictedDaemon = assay.eq (builtins.elem "vci" withToken.nix.settings.allowed-users) true;
    notAddedWhereUnrestricted = assay.eq (builtins.elem "vci" (plain.nix.settings.allowed-users or ["*"])) false;

    # A desktop shares the cache host: idle CPU and I/O, memory-capped, read-only system.
    yieldsToTheDesktop = assay.eq [svc.serviceConfig.Nice svc.serviceConfig.CPUSchedulingPolicy svc.serviceConfig.IOSchedulingClass svc.serviceConfig.MemoryMax] [19 "idle" "idle" "12G"];
    sandboxed = assay.eq [svc.serviceConfig.ProtectSystem svc.serviceConfig.ProtectHome svc.serviceConfig.NoNewPrivileges] ["strict" true true];
    writesOnlyItsState = assay.eq (lib.sort lib.lessThan svc.serviceConfig.ReadWritePaths) ["/var/lib/prometheus-node-exporter-text" "/var/lib/vci"];
    throughTheDaemon = assay.eq svc.environment.NIX_REMOTE "daemon";
    # `nix eval` of a git+file flake runs git from PATH (the VM test found it missing).
    gitOnPath = assay.eq (builtins.any (p: (p.pname or "") == "git") svc.path) true;
    plainErrors = assay.eq svc.environment.NO_COLOR "1";
    # A busy workstation makes it wait: the switch check needs systemctl; memory floor 10G;
    # the load limit is the CPU count unless one is set.
    waitsForAQuietHost = assay.eq [(has "--systemctl /nix/store/") (has "--min-free-memory 10G") (has "--max-load")] [true true false];
  }
