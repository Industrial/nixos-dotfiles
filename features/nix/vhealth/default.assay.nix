# Colocated suite for features/nix/vhealth/default.nix — probes declared by features, the
# JSON vhealth reads, and the sandboxed daemon writing node_exporter textfile metrics.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  fleet = import ../../../common/fleet.nix;
  hostLib = import ../../../lib/features.nix {inherit lib;};

  dir = "/var/lib/prometheus-node-exporter-text";
  failedAssertions = c: map (a: a.message) (lib.filter (a: !a.assertion) c.assertions);

  # A feature elsewhere declares probes of every type.
  declaring = {
    features.nix.vhealth.probes = {
      web = {
        type = "http";
        url = "http://127.0.0.1:8080/health";
        bodyContains = "ok";
      };
      ssh = {
        type = "tcp";
        host = "127.0.0.1";
        port = 22;
        timeout = 1000;
      };
      daemon = {
        type = "unix";
        path = "/nix/var/nix/daemon-socket/socket";
      };
      cmd = {
        type = "command";
        argv = ["/run/current-system/sw/bin/true"];
      };
      stamp = {
        type = "file";
        path = "/run/stamp";
        maxAge = 60;
        critical = false;
      };
    };
  };
  cfg = nixos.eval {modules = [./default.nix declaring];};
  # A host that restricts who may use the Nix daemon, as features/nixos/users does.
  restricted = nixos.eval {
    modules = [
      ./default.nix
      declaring
      {
        nix.settings.allowed-users = ["@wheel"];
        features.nix.vhealth.restrictedNixUsers = true;
      }
    ];
  };
  inherit ((builtins.fromJSON (builtins.unsafeDiscardStringContext cfg.features.nix.vhealth.probesJson))) probes;
  byName = builtins.listToAttrs (map (p: lib.nameValuePair p.name p) probes);

  service = cfg.systemd.services.vhealth;
  sc = service.serviceConfig;
  args = lib.splitString " " sc.ExecStart;
  argAfter = flag: let
    i = lib.lists.findFirstIndex (a: a == flag) null args;
  in
    if i == null
    then null
    else builtins.elemAt args (i + 1);

  incomplete = nixos.eval {
    modules = [
      ./default.nix
      {features.nix.vhealth.probes.half.type = "tcp";}
    ];
  };

  # Drakkar's own features, evaluated together with vhealth as on the host (probes declared
  # by vcache, vverify, the exporter and sshd, with the addresses common/fleet.nix holds).
  drakkar = nixos.eval {
    modules = [
      ./default.nix
      ../vcache/default.nix
      ../vverify/default.nix
      ../../monitoring/prometheus-exporter/default.nix
      ../../network/ssh/default.nix
    ];
    settings.hostname = "drakkar";
  };
  drakkarProbes = builtins.listToAttrs (map (p: lib.nameValuePair p.name p) (builtins.fromJSON (builtins.unsafeDiscardStringContext drakkar.features.nix.vhealth.probesJson)).probes);
  ip = fleet.hosts.drakkar.tailscaleIp;

  # The option is declarable from a host that has vhealth off: lib/features.nix keeps the
  # options of a disabled feature.
  wrappedOff = nixos.eval {
    modules = [
      (hostLib.feature ./default.nix)
      {
        features.nix.vhealth.probes.x = {
          type = "tcp";
          host = "h";
          port = 1;
        };
      }
    ];
  };
in
  assay.suite "vhealth-service" {
    # Every type reaches the JSON with exactly the fields config.vlt reads.
    jsonHasEveryProbe = assay.eq (map (p: p.name) probes) ["cmd" "daemon" "nix-daemon" "ssh" "stamp" "web"];
    httpFields = assay.eq byName.web {
      name = "web";
      type = "http";
      critical = true;
      timeoutMs = 5000;
      url = "http://127.0.0.1:8080/health";
      status = 200;
      bodyContains = "ok";
    };
    tcpFields = assay.eq byName.ssh {
      name = "ssh";
      type = "tcp";
      critical = true;
      timeoutMs = 1000;
      host = "127.0.0.1";
      port = 22;
    };
    unixFields = assay.eq byName.daemon.path "/nix/var/nix/daemon-socket/socket";
    commandFields = assay.eq byName.cmd.argv ["/run/current-system/sw/bin/true"];
    fileFields = assay.eq [byName.stamp.maxAgeSeconds byName.stamp.critical (byName.stamp ? maxAge)] [60 false false];
    noNulls = assay.eq (byName.web ? host || byName.ssh ? url) false;
    etcHasTheJson = assay.eq (cfg.environment.etc ? "vhealth/probes.json") true;

    # A probe without the fields its type needs is refused at evaluation.
    incompleteRefused = assay.eq (failedAssertions incomplete) ["features.nix.vhealth.probes.half: a tcp probe needs host, port."];
    completeAccepted = assay.eq (failedAssertions cfg) [];

    # The daemon: vhealth's own Schedule (no systemd timer), into the textfile directory.
    installsVhealth = assay.eq (nixos.hasPackage cfg "vhealth") true;
    runsTheDaemon = assay.eq (builtins.elemAt args 1) "daemon";
    readsTheGeneratedJson = assay.eq (builtins.match "/nix/store/[a-z0-9]+-vhealth-probes.json" (argAfter "--config") != null) true;
    everyMinute = assay.eq (argAfter "--interval") "1m";
    writesTheTextfileDir = assay.eq (argAfter "--textfile-dir") dir;
    noTimer = assay.eq (cfg.systemd.timers ? vhealth) false;
    startsAtBoot = assay.eq service.wantedBy ["multi-user.target"];
    restartsAlways = assay.eq sc.Restart "always";

    # Sandbox: the textfile directory is the one write; network allowed (it probes services).
    # A static system user, the identity vdeploy's post-switch check also runs as (#160).
    staticUser = assay.eq [sc.User sc.Group (sc.DynamicUser or false) cfg.users.users.vhealth.isSystemUser] ["vhealth" "vhealth" false true];
    # Where the host restricts the Nix daemon, vhealth is added to the list (merged, never
    # replacing it, never trusted); elsewhere nixpkgs' default stays.
    mayUseTheRestrictedDaemon =
      assay.eq [(lib.sort lib.lessThan restricted.nix.settings.allowed-users) (builtins.elem "vhealth" restricted.nix.settings.trusted-users)] [["@wheel" "vhealth"] false];
    leavesAnUnrestrictedDaemonAlone = assay.eq cfg.nix.settings.allowed-users ["*"];
    protectSystemStrict = assay.eq sc.ProtectSystem "strict";
    onlyWritesTheTextfileDir = assay.eq sc.ReadWritePaths [dir];
    writesThroughTheTextfileGroup = assay.eq [sc.SupplementaryGroups sc.UMask] [["prometheus-textfile"] "0022"];
    networkForProbes = assay.eq [(sc.PrivateNetwork or false) sc.RestrictAddressFamilies] [false ["AF_INET" "AF_INET6" "AF_UNIX"]];
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

    # The shared textfile directory, once, however many writers import it.
    textfileDirCreated = assay.eq (builtins.length (builtins.filter (r: r == "d ${dir} 2775 root prometheus-textfile - -") drakkar.systemd.tmpfiles.rules)) 1;
    exporterReadsTheDirOnce = assay.eq (builtins.filter (lib.hasPrefix "--collector.textfile") drakkar.services.prometheus.exporters.node.extraFlags) ["--collector.textfile.directory=${dir}"];

    # What drakkar runs today, each declared by its own feature, at fleet.nix's address.
    drakkarProbes = assay.eq (builtins.attrNames drakkarProbes) ["nix-daemon" "node-exporter" "sshd" "vcache" "vverify-metrics"];
    vcacheProbe = assay.eq [drakkarProbes.vcache.url drakkarProbes.vcache.bodyContains] ["http://${ip}:${toString fleet.cachePort}/nix-cache-info" "StoreDir: /nix/store"];
    nodeExporterProbe = assay.eq drakkarProbes.node-exporter.url "http://${ip}:${toString drakkar.services.prometheus.exporters.node.port}/metrics";
    sshdProbe = assay.eq [drakkarProbes.sshd.host drakkarProbes.sshd.port] [ip 22];
    # A store query through the daemon, not a connect: the socket can accept with no daemon.
    nixDaemonAnswers =
      assay.eq [drakkarProbes.nix-daemon.type drakkarProbes.nix-daemon.critical (lib.hasSuffix "/bin/nix-store" (builtins.head drakkarProbes.nix-daemon.argv)) (builtins.tail drakkarProbes.nix-daemon.argv)] ["command" true true ["--store" "daemon" "--query" "--hash" "/run/current-system"]];
    vverifyFreshness = assay.eq [drakkarProbes.vverify-metrics.path drakkarProbes.vverify-metrics.maxAgeSeconds drakkarProbes.vverify-metrics.critical] ["${dir}/vverify.prom" 691200 false];
    # Not literals: evaluated as another host, the same features probe that host's address.
    addressesFollowTheHost = let
      mimir = nixos.eval {
        modules = [./default.nix ../../monitoring/prometheus-exporter/default.nix ../../network/ssh/default.nix];
        settings.hostname = "mimir";
      };
      p = builtins.listToAttrs (map (x: lib.nameValuePair x.name x) (builtins.fromJSON (builtins.unsafeDiscardStringContext mimir.features.nix.vhealth.probesJson)).probes);
      m = fleet.hosts.mimir.tailscaleIp;
    in
      assay.eq [p.sshd.host p.node-exporter.url] [m "http://${m}:9002/metrics"];

    # Declarable from any feature, on a host where vhealth is off.
    declarableWhileOff =
      assay.eq [wrappedOff.features.nix.vhealth.enable (builtins.attrNames wrappedOff.features.nix.vhealth.probes) (wrappedOff.systemd.services ? vhealth)] [false ["x"] false];
  }
