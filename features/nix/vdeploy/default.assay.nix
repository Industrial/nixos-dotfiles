# Colocated suite for features/nix/vdeploy/default.nix — the observe-mode deploy agent:
# its service, what it is told (and never told: to switch), the dotfiles checkout, the
# textfile metrics, and deploy mode (comin gone, GH-225).
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;

  dir = "/var/lib/prometheus-node-exporter-text";
  base = {
    networking.hostName = "testhost";
    users.users.alice = {
      isNormalUser = true;
      home = "/home/alice";
    };
    features.nix.vdeploy.dotfiles.user = "alice";
  };
  cfg = nixos.eval {modules = [./default.nix base];};
  # vverify and vhealth write textfile metrics too: all three import the one
  # textfile-collector module, so the exporter's flag and the directory are there once.
  withOtherWriters = nixos.eval {
    modules = [
      ./default.nix
      ../vverify/default.nix
      ../vhealth/default.nix
      base
      {services.prometheus.exporters.node.enable = true;}
    ];
  };
  # mimir (GH-221): its debounce is a host fact in common/fleet.nix.
  mimir = nixos.eval {
    modules = [./default.nix base];
    settings.hostname = "mimir";
  };
  withExporter = nixos.eval {
    modules = [
      ./default.nix
      base
      {services.prometheus.exporters.node.enable = true;}
    ];
  };
  noDotfiles = nixos.eval {modules = [./default.nix base {features.nix.vdeploy.dotfiles.enable = false;}];};
  slow = nixos.eval {modules = [./default.nix base {features.nix.vdeploy.debounce = "15m";}];};

  # Deploy mode (#160). `services.comin.enable` stands in for comin's module, which hosts
  # import (features/fleet/comin), off as on drakkar and mimir since GH-225; vhealth's
  # probes file for features/nix/vhealth.
  fleet = {
    options.services.comin.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };
  probes = {environment.etc."vhealth/probes.json".text = ''{"probes": []}'';};
  deployed = nixos.eval {modules = [./default.nix base fleet probes {features.nix.vdeploy.mode = "deploy";}];};
  # A deploy-mode host that left comin on: two deployers.
  withComin = nixos.eval {modules = [./default.nix base fleet probes {features.nix.vdeploy.mode = "deploy";} {services.comin.enable = true;}];};
  # The fleet's `vdeploy` role picks deploy mode: a host without it observes.
  byRole = host: (nixos.eval {modules = [./default.nix base fleet probes {features.nix.vdeploy.host = host;}];}).features.nix.vdeploy.mode;
  # GH-221: commit verification's one rollback option.
  unsignedOk = nixos.eval {modules = [./default.nix base {features.nix.vdeploy.requireSignedCommits = lib.mkForce false;}];};
  noKeys = nixos.eval {modules = [./default.nix base {features.nix.vdeploy.trustedSigningKeys = [];}];};
  noVhealth = nixos.eval {modules = [./default.nix base fleet {features.nix.vdeploy.mode = "deploy";}];};
  failedAssertions = c: map (a: a.message) (builtins.filter (a: !a.assertion && lib.hasPrefix "features.nix.vdeploy" a.message) c.assertions);
  dargAfter = argAfterIn deployed;

  service = cfg.systemd.services.vdeploy;
  sc = service.serviceConfig;
  argsOf = c: lib.splitString " " c.systemd.services.vdeploy.serviceConfig.ExecStart;
  args = argsOf cfg;
  argAfterIn = c: flag: let
    a = argsOf c;
    i = lib.lists.findFirstIndex (x: x == flag) null a;
  in
    if i == null
    then null
    else builtins.elemAt a (i + 1);
  argAfter = argAfterIn cfg;
in
  assay.suite "vdeploy-service" {
    installsVdeploy = assay.eq (nixos.hasPackage cfg "vdeploy") true;
    runsTheInstalledBinary =
      assay.eq (builtins.match "/nix/store/[a-z0-9]+-vdeploy-[^/]+/bin/vdeploy" (builtins.head args) != null) true;
    startsAtBoot = assay.eq service.wantedBy ["multi-user.target"];
    waitsForTheNetwork = assay.eq [(builtins.elem "network-online.target" service.after) (builtins.elem "network-online.target" service.wants)] [true true];

    # Observe mode: a daemon on its own Schedule, and nothing on its command line or in
    # its unit that switches a system.
    daemonNotOnce = assay.eq (builtins.elem "--once" args) false;
    noTimer = assay.eq (cfg.systemd.timers ? vdeploy) false;
    neverSwitches =
      assay.eq (builtins.any (a: lib.hasInfix "switch" a) args || lib.hasInfix "switch-to-configuration" (toString (sc.ExecStartPost or ""))) false;

    # What it polls and evaluates.
    # The flake's host name is the fleet's settings.hostname (the assay harness's here),
    # which wins over networking.hostName.
    thisHost = assay.eq (argAfter "--host") "assay-host";
    pollsMainOfTheRepo = assay.eq [(argAfter "--url") (argAfter "--branch")] ["https://github.com/Industrial/nixos-dotfiles.git" "main"];
    everyMinute = assay.eq (argAfter "--interval") "1m";
    noDebounceByDefault = assay.eq (argAfter "--debounce") "0";
    debouncePerHost = assay.eq (argAfterIn slow "--debounce") "15m";
    # The slow host waits for main to go quiet, from common/fleet.nix; it deploys (the
    # vdeploy role, GH-160), and keeps the debounce.
    mimirDebouncesFromFleet =
      assay.eq [(argAfterIn mimir "--host") (argAfterIn mimir "--debounce") mimir.features.nix.vdeploy.mode] ["mimir" "2m" "deploy"];
    ownCloneNotTheUsers = assay.eq (argAfter "--repo") "/var/lib/vdeploy/repo";
    nixThroughTheDaemon = assay.eq service.environment.NIX_REMOTE "daemon";
    homeInTheStateDir = assay.eq [service.environment.HOME sc.StateDirectory] ["/var/lib/vdeploy" "vdeploy"];
    diffsOnTheStoreDatabase = assay.eq (argAfter "--db") "/nix/var/nix/db/db.sqlite";
    gitAndNixPinned =
      assay.eq [(lib.hasSuffix "/bin/git" (argAfter "--git")) (lib.hasSuffix "/bin/nix" (argAfter "--nix"))] [true true];

    # Commit verification (GH-221): on by default, against a keyring built from the pinned
    # GitHub key, with gpgv from the store.
    requiresSignedCommitsByDefault =
      assay.eq [cfg.features.nix.vdeploy.requireSignedCommits (builtins.elem "--require-signed" args)] [true true];
    trustsThePinnedGithubKey =
      assay.eq (map baseNameOf (map toString cfg.features.nix.vdeploy.trustedSigningKeys)) ["github-web-flow.asc"];
    keyringBuiltInTheStore =
      assay.eq [(lib.hasSuffix "-vdeploy-trusted-keys.gpg" (argAfter "--trusted-keys")) (lib.hasSuffix "/bin/gpgv" (argAfter "--gpgv"))] [true true];
    # The pinned file holds GitHub's current web-flow key, by fingerprint.
    pinnedKeyNamesItsFingerprint =
      assay.eq (lib.hasInfix "9684 79A1 AFF9 27E3 7D1A  566B B569 0EEE BB95 2194" (builtins.readFile ../../../rust/tools/vdeploy/keys/github-web-flow.asc)) true;
    # The rollback: nothing refused, the verdict still checked and recorded.
    rollbackStopsRequiringSignatures =
      assay.eq [(builtins.elem "--require-signed" (argsOf unsignedOk)) (argAfterIn unsignedOk "--trusted-keys" != null)] [false true];
    requiringSignaturesNeedsAKey = assay.eq (builtins.length (failedAssertions noKeys)) 1;

    # The user's checkout, fast-forwarded as the user.
    fastForwardsTheUsersCheckout =
      assay.eq [(argAfter "--dotfiles") (argAfter "--dotfiles-user") (argAfter "--dotfiles-group") (argAfter "--dotfiles-home")] ["/home/alice/.dotfiles" "alice" "users" "/home/alice"];
    checkoutIsWritable = assay.eq (builtins.elem "-/home/alice/.dotfiles" sc.ReadWritePaths) true;
    dropsToTheUser = assay.eq (builtins.all (p: builtins.elem p sc.CapabilityBoundingSet) ["CAP_SETUID" "CAP_SETGID"]) true;
    dotfilesCanBeOff = assay.eq [(builtins.elem "--dotfiles" (argsOf noDotfiles)) noDotfiles.systemd.services.vdeploy.serviceConfig.ReadWritePaths] [false [dir]];

    # Metrics into the node_exporter textfile directory, readable by the exporter.
    writesTheTextfileDir = assay.eq (argAfter "--textfile-dir") dir;
    filesReadableByTheExporter = assay.eq sc.UMask "0022";
    textfileDirCreated = assay.eq (builtins.elem "d ${dir} 2775 root prometheus-textfile - -" cfg.systemd.tmpfiles.rules) true;
    exporterReadsTheDir =
      assay.eq (builtins.elem "--collector.textfile.directory=${dir}" withExporter.services.prometheus.exporters.node.extraFlags) true;
    # node_exporter refuses the flag twice: with vverify on, it is vverify's alone.
    flagOnceBesideOtherWriters = let
      flags = builtins.filter (f: f == "--collector.textfile.directory=${dir}") withOtherWriters.services.prometheus.exporters.node.extraFlags;
      rules = builtins.filter (r: r == "d ${dir} 2775 root prometheus-textfile - -") withOtherWriters.systemd.tmpfiles.rules;
    in
      assay.eq [(builtins.length flags) (builtins.length rules)] [1 1];

    # Deploy mode (#160): the take-over.
    observeByDefault = assay.eq [cfg.features.nix.vdeploy.mode (builtins.elem "--mode" args)] ["observe" false];
    modeFollowsTheFleetRole = let
      fleetData = import ../../../common/fleet.nix;
      expect = h:
        if fleetData.hasRole "vdeploy" h
        then "deploy"
        else "observe";
    in
      assay.eq (map byRole (fleetData.order ++ ["not-in-the-fleet"])) (map expect fleetData.order ++ ["observe"]);
    deployModeOnTheCommandLine = assay.eq (dargAfter "--mode") "deploy";
    healthWindowTwoMinutes = assay.eq (dargAfter "--health-window") "2m";
    appliesThroughTransientUnits =
      assay.eq [(lib.hasSuffix "/bin/systemd-run" (dargAfter "--systemd-run")) (lib.hasSuffix "/bin/systemctl" (dargAfter "--systemctl"))] [true true];
    writesTheSystemProfile = assay.eq (dargAfter "--profile") "/nix/var/nix/profiles/system";
    rootsTheCandidate =
      assay.eq [(dargAfter "--gcroot") (builtins.elem "d /nix/var/nix/gcroots/vdeploy 0755 root root - -" deployed.systemd.tmpfiles.rules)] ["/nix/var/nix/gcroots/vdeploy/candidate" true];
    profileToolsPinned =
      assay.eq [(lib.hasSuffix "/bin/nix-env" (dargAfter "--nix-env")) (lib.hasSuffix "/bin/nix-store" (dargAfter "--nix-store"))] [true true];
    # The probes run as the vhealth user (setpriv), as vhealth's own daemon runs them.
    healthAsVhealth =
      assay.eq [(dargAfter "--health-as") (lib.hasSuffix "/bin/setpriv" (dargAfter "--setpriv"))] ["vhealth" true];
    # The by-hand apply, the same transient unit the daemon uses; deploy mode only.
    applyWrapper = assay.eq [(nixos.hasPackage deployed "vdeploy-apply") (nixos.hasPackage cfg "vdeploy-apply")] [true false];
    # comin is gone (GH-225): no tombstone unit, and nothing forces comin off any more.
    noCominTombstone = assay.eq [(deployed.systemd.services ? comin) deployed.services.comin.enable] [false false];
    # Deploy mode with comin still on is refused at evaluation, not papered over.
    deployRefusesComin = assay.eq (builtins.any (lib.hasInfix "turn comin off") (failedAssertions withComin)) true;
    # The one rollback is `fleet deploy <host> --legacy` (deploy-rs): flake.assay.nix's
    # vdeployHostsKeepTheLegacyRollback, and bin/dev.d/test.sh for bin/fleet's flag.
    # keep-or-rollback needs vhealth's probes.
    deployNeedsVhealth = assay.eq [(failedAssertions deployed) (builtins.length (failedAssertions noVhealth))] [[] 1];

    # Sandbox.
    protectSystemStrict = assay.eq [sc.ProtectSystem sc.ProtectHome] ["strict" "read-only"];
    stopsWithSigint = assay.eq [sc.KillSignal sc.SuccessExitStatus] ["SIGINT" [130]];
    restartsOnFailure = assay.eq sc.Restart "on-failure";
    hardened = assay.subset sc {
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictNamespaces = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
    };

    # GH-246, the wake: deploy mode only, a FIFO only the operators may write, and the poll on
    # `interval` still the default (the flag adds a trigger, it removes nothing).
    wakeInDeployModeOnly = assay.eq [(lib.hasInfix "--wake-fifo /run/vdeploy/wake" deployed.systemd.services.vdeploy.serviceConfig.ExecStart) (lib.hasInfix "--wake-fifo" cfg.systemd.services.vdeploy.serviceConfig.ExecStart)] [true false];
    pollStaysTheDefault = assay.eq (lib.hasInfix "--interval " deployed.systemd.services.vdeploy.serviceConfig.ExecStart) true;
    wakeFifoForTheOperatorsOnly = assay.eq (builtins.elem "p /run/vdeploy/wake 0620 root vdeploy-wake - -" deployed.systemd.tmpfiles.rules) true;
    wakeGroupIsTheOperator = assay.eq deployed.users.groups.vdeploy-wake.members ["alice"];
    # Never a service or system user: nobody, vhealth, vci, root, or anything isSystemUser.
    wakeGroupHasNoSystemUser = let
      inherit (deployed.users.groups.vdeploy-wake) members;
      system = u: builtins.elem u ["root" "nobody" "vhealth" "vci" "vdeploy"] || (deployed.users.users.${u}.isSystemUser or false);
    in
      assay.eq (builtins.filter system members) [];
    wakeRefusesASystemOperator = let
      withNobody = nixos.eval {modules = [./default.nix base fleet probes {features.nix.vdeploy.mode = "deploy";} {features.nix.vdeploy.wake.operators = ["nobody"];}];};
    in
      assay.eq (builtins.any (lib.hasInfix "nobody must be a normal (operator) user") (failedAssertions withNobody)) true;
    # What `vdeploy wake --wait` reads (status.json, plan.json, last.json) is readable by the
    # operator: a 0755 state directory, 0644 files.
    # A host with no such user (a test node) has no operator, never a stand-in, and evaluates.
    noOperatorWithoutTheUser = let
      bare = nixos.eval {modules = [./default.nix fleet probes {networking.hostName = "testhost";} {features.nix.vdeploy.mode = "deploy";} {features.nix.vdeploy.dotfiles.enable = false;}];};
    in
      assay.eq [bare.users.groups.vdeploy-wake.members (failedAssertions bare)] [[] []];
    waitReadsReadableFiles = assay.eq [deployed.systemd.services.vdeploy.serviceConfig.StateDirectoryMode deployed.systemd.services.vdeploy.serviceConfig.UMask] ["0755" "0022"];
    # The one rollback: wake.enable = false; no flag, no FIFO, the interval as before.
    wakeRollsBack = let
      off = nixos.eval {modules = [./default.nix base fleet probes {features.nix.vdeploy.mode = "deploy";} {features.nix.vdeploy.wake.enable = false;}];};
    in
      assay.eq [(lib.hasInfix "--wake-fifo" off.systemd.services.vdeploy.serviceConfig.ExecStart) (builtins.any (lib.hasInfix "/run/vdeploy/wake") off.systemd.tmpfiles.rules)] [false false];
  }
