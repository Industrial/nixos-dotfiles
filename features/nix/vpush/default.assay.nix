# Colocated suite for features/nix/vpush/default.nix — the post-build-hook and the spool
# daemon that push a builder's closures to the fleet cache.
#
# Evaluated as huginn (a builder-role host that is not a cache), so the cache the claims
# expect is the first other entry of common/fleet.nix's binaryCaches, not a literal.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  fleet = import ../../../common/fleet.nix;

  pusher = lib.findFirst (n: fleet.hasRole "builder" n && !(fleet.isCacheIn fleet.hosts n)) null fleet.order;
  cacheHost = (lib.findFirst (c: c.name != pusher) null fleet.binaryCaches).name;
  evalAs = hostname: extra:
    nixos.eval {
      modules = [./default.nix] ++ extra;
      settings.hostname = hostname;
    };
  cfg = evalAs pusher [];
  service = cfg.systemd.services.vpush;
  sc = service.serviceConfig;
  exec = sc.ExecStart;
  has = s: lib.hasInfix s exec;
  # The built hook script (a shell script in the store, the artifact itself, not Nix source).
  hookPath = cfg.nix.settings.post-build-hook;
  hookScript = builtins.readFile hookPath;

  failedAssertions = c: map (a: a.message) (lib.filter (a: !a.assertion) c.assertions);

  # With features.hardening.storeSigning on (the real users module), the host's store key
  # is handed over too.
  signingCfg = evalAs pusher [
    ../../nixos/users/default.nix
    {
      features.hardening.storeSigning = {
        enable = true;
        publicKeys = ["${pusher}-1:AAAA"];
      };
    }
  ];
  signingSc = signingCfg.systemd.services.vpush.serviceConfig;

  # A cache host never pushes to itself: enabling vpush there is refused.
  cacheName = (builtins.head fleet.binaryCaches).name;
in
  assay.suite "vpush" {
    installsVpush = assay.eq (nixos.hasPackage cfg "vpush") true;

    # The hook: vpush's spooler, behind a wrapper that always exits 0.
    setsThePostBuildHook = assay.eq (builtins.match "/nix/store/[a-z0-9]+-vpush-post-build-hook" (toString cfg.nix.settings.post-build-hook) != null) true;
    hookNeverFailsTheBuild =
      assay.eq (lib.hasInfix "\nexit 0" hookScript) true;
    hookSpoolsIntoTheStateDir = assay.eq (lib.hasInfix "vpush hook --spool /var/lib/vpush/spool" hookScript) true;

    # The daemon: the installed binary, draining the same spool, to the fleet cache.
    runsTheInstalledBinary = assay.eq (builtins.match "/nix/store/[a-z0-9]+-vpush-[^/]+/bin/vpush daemon .*" exec != null) true;
    drainsTheHooksSpool = assay.eq (has "--spool /var/lib/vpush/spool") true;
    pushesToTheFleetCache = assay.eq (has "--ssh tom@${fleet.hosts.${cacheHost}.tailscaleIp} ") true;
    cacheComesFromBinaryCaches = assay.eq cfg.features.nix.vpush.sshDestination "tom@${fleet.hosts.${cacheHost}.tailscaleIp}";
    runsTheDaemonOverStdio = assay.eq (has "--remote-command '/run/current-system/sw/bin/nix-daemon --stdio'") true;
    usesTheCredentialKey = assay.eq (has "--ssh-arg -i --ssh-arg %d/ssh-key") true;
    learnsTheHostKeyOnce = assay.eq (has "--ssh-arg 'StrictHostKeyChecking=accept-new'") true;
    neverPrompts = assay.eq (has "--ssh-arg 'BatchMode=yes'") true;

    # Trust: the operator key by default (trusted on the cache), no signing key unless
    # storeSigning is on.
    operatorKeyAsCredential = assay.eq sc.LoadCredential ["ssh-key:/home/tom/.ssh/id_ed25519"];
    noSigningKeyByDefault = assay.eq (has "--sign-key-file") false;
    storeSigningKeyHandedOver = assay.eq signingSc.LoadCredential ["ssh-key:/home/tom/.ssh/id_ed25519" "sign-key:/var/lib/nix-signing/secret-key"];
    signsWithTheCredential = assay.eq (lib.hasInfix "--sign-key-file %d/sign-key" signingSc.ExecStart) true;

    # Supervised and started at boot.
    startsAtBoot = assay.eq service.wantedBy ["multi-user.target"];
    restartsAlways = assay.eq [sc.Restart service.startLimitIntervalSec] ["always" 0];

    # The spool exists before the first build, owned by the service user.
    spoolCreatedAtBoot = assay.eq (builtins.elem "d /var/lib/vpush/spool 0700 vpush vpush -" cfg.systemd.tmpfiles.rules) true;
    staticSystemUser = assay.eq [cfg.users.users.vpush.isSystemUser sc.User sc.StateDirectory] [true "vpush" "vpush"];

    # Sandbox.
    protectSystemStrict = assay.eq sc.ProtectSystem "strict";
    readsStoreAndDbReadOnly = assay.eq sc.ReadOnlyPaths ["/nix/store" "/nix/var/nix/db"];
    noCapabilities = assay.eq [sc.CapabilityBoundingSet sc.AmbientCapabilities sc.NoNewPrivileges] [[""] [""] true];
    hardened = assay.subset sc {
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      RestrictNamespaces = true;
      MemoryDenyWriteExecute = true;
    };

    # A pusher evaluates cleanly; a cache host refuses vpush.
    pusherEvaluatesCleanly = assay.eq (failedAssertions cfg) [];
    cacheHostRefused = assay.eq (lib.any (m: lib.hasInfix "a cache never pushes to itself" m) (failedAssertions (evalAs cacheName []))) true;
  }
