# Colocated suite for common/nix-daemon-listen.nix — the oneshot that rebinds
# nix-daemon.socket after a live switch moves it (into vdaemon-proxy, and back out).
let
  assay = import ./assay/default.nix;
  nixos = import ./assay/nixos.nix;
  inherit (nixos) lib;

  public = "/nix/var/nix/daemon-socket/socket";
  upstream = "/nix/var/nix/daemon-socket-upstream/socket";

  alone = (nixos.eval {modules = [./nix-daemon-listen.nix];}).systemd.services.nix-daemon-listen;
  withProxy = (nixos.eval {modules = [./nix-daemon-listen.nix ../features/nix/vdaemon-proxy/default.nix];}).systemd.services.nix-daemon-listen;
  script = builtins.readFile alone.serviceConfig.ExecStart;
  # Where each step of the rebind sits in the script.
  at = needle: lib.length (lib.splitString "\n" (lib.head (lib.splitString needle script)));
in
  assay.suite "nix-daemon-listen" {
    # Without the feature (every other host, and the rollback) it guards the public path.
    guardsThePublicPathByDefault = assay.eq alone.environment.NIX_DAEMON_LISTEN public;
    # With it, the private one the proxy connects to. The path differs between the two
    # configurations, so a switch either way changes (and restarts) the unit.
    guardsTheUpstreamPathWithTheProxy = assay.eq withProxy.environment.NIX_DAEMON_LISTEN upstream;

    # Runs at boot and stays active, so switch-to-configuration restarts it when it changes.
    atBoot = assay.eq alone.wantedBy ["multi-user.target"];
    oneshotRemainsActive = assay.eq [alone.serviceConfig.Type alone.serviceConfig.RemainAfterExit] ["oneshot" true];
    afterTheSocket = assay.eq (builtins.elem "nix-daemon.socket" alone.after) true;

    # The rebind: stop the accepting process (KillMode=process keeps builds), rebind the
    # socket, start the daemon again, in that order, and only when nothing answers.
    checksBeforeActing = assay.eq (lib.hasInfix "store info --store \"unix://$NIX_DAEMON_LISTEN\"" script) true;
    rebindsInOrder =
      assay.eq [(at "stop nix-daemon.service" < at "restart nix-daemon.socket") (at "restart nix-daemon.socket" < at "start nix-daemon.service")] [true true];
    failsWhenStillDead = assay.eq (lib.hasInfix "after the rebind\" >&2\nexit 1" script) true;
  }
