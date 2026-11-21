# Colocated suite for features/nix/vdeploy/default.nix — the observe-mode deploy agent:
# its service, what it is told (and never told: to switch), the dotfiles checkout, the
# textfile metrics, and that it sits next to comin rather than replacing it.
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
  # vverify already declares the textfile directory and the exporter's flag.
  withVverify = nixos.eval {
    modules = [
      ./default.nix
      base
      {
        options.features.nix.vverify.enable = lib.mkOption {default = true;};
        config.services.prometheus.exporters.node.enable = true;
      }
    ];
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
    ownCloneNotTheUsers = assay.eq (argAfter "--repo") "/var/lib/vdeploy/repo";
    nixThroughTheDaemon = assay.eq service.environment.NIX_REMOTE "daemon";
    homeInTheStateDir = assay.eq [service.environment.HOME sc.StateDirectory] ["/var/lib/vdeploy" "vdeploy"];
    diffsOnTheStoreDatabase = assay.eq (argAfter "--db") "/nix/var/nix/db/db.sqlite";
    gitAndNixPinned =
      assay.eq [(lib.hasSuffix "/bin/git" (argAfter "--git")) (lib.hasSuffix "/bin/nix" (argAfter "--nix"))] [true true];

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
    noSecondFlagBesideVverify =
      assay.eq [withVverify.services.prometheus.exporters.node.extraFlags (builtins.elem "d ${dir} 2775 root prometheus-textfile - -" withVverify.systemd.tmpfiles.rules)] [[] false];

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
  }
