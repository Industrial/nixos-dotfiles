# Colocated suite for features/nix/vdaemon-proxy/test-live-switch.nix — the VM test that
# switches the feature into and out of a running system.
#
# Evaluates the test's node (no VM is booted here), so these claims are about the machine
# under test: no proxy at boot, the rebind oneshot every host carries, and the proxy in
# the specialisation it switches to.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./test-live-switch.nix {inherit pkgs;};
  inherit (test.nodes) machine;
in
  assay.suite "vdaemon-proxy-live-switch-vm-test" {
    named = assay.eq test.name "vm-test-run-vdaemon-proxy-live-switch";
    bootsWithoutTheProxy = assay.eq (machine.systemd.sockets ? vdaemon-proxy) false;
    bootsWithTheRebind = assay.eq machine.systemd.services.nix-daemon-listen.environment.NIX_DAEMON_LISTEN "/nix/var/nix/daemon-socket/socket";
    switchesToTheProxySpecialisation = assay.eq (machine.specialisation ? proxy) true;
    aliceIsUntrusted = assay.eq (builtins.elem "alice" machine.nix.settings.trusted-users) false;
  }
