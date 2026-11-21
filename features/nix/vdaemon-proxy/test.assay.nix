# Colocated suite for features/nix/vdaemon-proxy/test.nix — the VM test that drives Nix
# through the proxy as an untrusted user, kills the proxy, and checks the fallback.
#
# Evaluates the test's node (no VM is booted here; `nix build
# .#checks.x86_64-linux.vdaemon-proxy-vm` runs it), so these claims are about the machine
# under test: the feature, the untrusted user, and what the trivial build needs.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./test.nix {inherit pkgs;};
  inherit (test.nodes) machine;
in
  assay.suite "vdaemon-proxy-vm-test" {
    named = assay.eq test.name "vm-test-run-vdaemon-proxy";
    runsTheFeature = assay.eq [(machine.systemd.services ? vdaemon-proxy) (machine.systemd.sockets ? vdaemon-proxy)] [true true];
    hasTheFallback = assay.eq (machine.systemd.services ? vdaemon-proxy-fallback) true;
    # alice is an ordinary user: not root, not trusted, so her nix goes through the daemon.
    aliceIsUntrusted =
      assay.eq [machine.users.users.alice.isNormalUser (builtins.elem "alice" machine.nix.settings.trusted-users)] [true false];
    # The trivial derivation's builder is in the VM's store.
    builderInTheStore = assay.eq (map (d: d.pname or d.name) machine.system.extraDependencies) ["busybox"];
    nixCommandEnabled = assay.eq (builtins.elem "nix-command" machine.nix.settings.experimental-features) true;
  }
