# Colocated suite for features/nix/vdaemon-proxy/default.nix — the proxy on the public
# daemon socket, the real daemon on a private one, and the fallback that keeps Nix
# reachable when the proxy cannot run. Claims read the evaluated units, so they hold
# for what systemd is given. ./test.nix runs the same arrangement in a VM.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  features = import ../../../lib/features.nix {inherit lib;};

  cfg = nixos.eval {modules = [./default.nix];};
  sockets = cfg.systemd.sockets;
  services = cfg.systemd.services;
  proxySocket = sockets.vdaemon-proxy;
  proxy = services.vdaemon-proxy;
  sc = proxy.serviceConfig;
  daemonSocket = sockets.nix-daemon.socketConfig;
  unitText = name: cfg.systemd.units.${name}.text;
  fallback = services.vdaemon-proxy-fallback;
  fsc = fallback.serviceConfig;
  gaveUpScript = builtins.readFile fsc.ExecCondition;

  public = "/nix/var/nix/daemon-socket/socket";
  upstream = "/nix/var/nix/daemon-socket-upstream/socket";

  enabledBy = modules: features.enabledFeatures (features.evalSelection {inherit modules;});
in
  assay.suite "vdaemon-proxy" {
    # In the catalog, off unless a host turns it on.
    offByDefault = assay.eq (builtins.elem "nix.vdaemon-proxy" (enabledBy [])) false;
    onWhenEnabled = assay.eq (builtins.elem "nix.vdaemon-proxy" (enabledBy [{features.nix.vdaemon-proxy.enable = true;}])) true;

    installsTheProxy = assay.eq (nixos.hasPackage cfg "vdaemon-proxy") true;

    # The real daemon moves: its own ListenStream reset, then the private path, owner-only.
    daemonSocketMoved = assay.eq daemonSocket.ListenStream ["" upstream];
    daemonSocketPrivate = assay.eq [daemonSocket.SocketMode daemonSocket.DirectoryMode] ["0600" "0700"];
    daemonUnitListensPrivately =
      assay.eq [(lib.hasInfix "ListenStream=\nListenStream=${upstream}" (unitText "nix-daemon.socket")) (lib.hasInfix "ListenStream=${public}" (unitText "nix-daemon.socket"))] [true false];

    # The proxy holds the public path, open to every user like the daemon's was, from boot.
    proxyOnThePublicPath = assay.eq proxySocket.socketConfig.ListenStream public;
    proxySocketOpen = assay.eq proxySocket.socketConfig.SocketMode "0666";
    proxySocketAtBoot = assay.eq proxySocket.wantedBy ["sockets.target"];
    proxyFindsUpstream = assay.eq proxy.environment.VDAEMON_UPSTREAM upstream;
    proxyRunsTheInstalledBinary =
      assay.eq (builtins.match "/nix/store/[a-z0-9]+-vdaemon-proxy-[^/]+/bin/vdaemon-proxy" sc.ExecStart != null) true;
    proxyNeedsBothSockets = assay.eq (lib.all (s: builtins.elem s proxy.requires) ["vdaemon-proxy.socket" "nix-daemon.socket"]) true;

    # Root with only the capabilities the per-connection uid switch needs.
    onlySetuidCapabilities = assay.eq sc.CapabilityBoundingSet "CAP_SETUID CAP_SETGID";
    noNewPrivileges = assay.eq sc.NoNewPrivileges true;
    unixSocketsOnly = assay.eq sc.RestrictAddressFamilies ["AF_UNIX"];
    readOnlyButTheUpstreamDirectory = assay.eq [sc.ProtectSystem sc.ReadWritePaths] ["strict" ["-/nix/var/nix/daemon-socket-upstream"]];

    # Crash safety: restarted at once; after repeated failure, the fallback runs.
    restartsAlways = assay.eq [sc.Restart sc.RestartSec] ["always" "100ms"];
    startLimitBounded = assay.eq [proxy.startLimitIntervalSec proxy.startLimitBurst] [30 10];
    failureRunsTheFallback = assay.eq proxy.unitConfig.OnFailure ["vdaemon-proxy-fallback.service"];
    # OnFailure= fires at every crash; the fallback runs only once systemd gave up.
    fallbackOnlyAtTheStartLimit = assay.eq (lib.hasInfix ''if [ "$result" = start-limit-hit ]; then'' gaveUpScript) true;
    fallbackSkipsOtherwise = assay.eq (lib.hasInfix "\nexit 1" gaveUpScript) true;
    # Started at every proxy failure, so a start limit of its own would fire first.
    fallbackHasNoStartLimit = assay.eq fallback.startLimitIntervalSec 0;
    fallbackNotAtBoot = assay.eq (fallback.wantedBy or []) [];
    # The real daemon, binding the public path itself (no socket unit is involved).
    fallbackRunsNixDaemon = assay.eq (lib.hasSuffix "/bin/nix-daemon nix-daemon --daemon" fsc.ExecStart) true;
    fallbackHasTheDaemonsEnvironment =
      assay.eq (fallback.environment.CURL_CA_BUNDLE or null) (services.nix-daemon.environment.CURL_CA_BUNDLE or null);
    # Each side stops the other; never Conflicts=, which would stop the socket even
    # when the fallback skips.
    fallbackStopsTheProxySocket = assay.eq (lib.hasSuffix "stop vdaemon-proxy.socket" fsc.ExecStartPre) true;
    proxySocketStopsTheFallback = assay.eq (lib.hasSuffix "stop --no-block vdaemon-proxy-fallback.service" proxySocket.socketConfig.ExecStartPre) true;
    noConflicts = assay.eq [(proxySocket.conflicts or []) (fallback.conflicts or [])] [[] []];
    # A stop racing the other's bind must not delete the file.
    noRemoveOnStop = assay.eq (proxySocket.socketConfig.RemoveOnStop or false) false;

    # The VM test is a flake check.
    vmTestInFlakeChecks = assay.eq (lib.hasInfix "vdaemon-proxy-vm = import ./features/nix/vdaemon-proxy/test.nix" (builtins.readFile ../../../flake.nix)) true;
  }
