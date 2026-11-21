# Colocated suite for features/nix/vdaemon-proxy/test-conformance.nix — the VM test that
# switches conformance mode into and out of a running system while builds and GCs race
# the queries.
#
# Evaluates the test's node (no VM is booted here), so these claims are about the machine
# under test: no proxy at boot, the rebind oneshot every host carries, and conformance
# mode in the specialisation it switches to.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./test-conformance.nix {inherit pkgs;};
  inherit (test.nodes) machine;
in
  assay.suite "vdaemon-proxy-conformance-vm-test" {
    named = assay.eq test.name "vm-test-run-vdaemon-proxy-conformance";
    # Rule 17: the proxy arrives by a live switch, not at boot.
    bootsWithoutTheProxy = assay.eq (machine.systemd.sockets ? vdaemon-proxy) false;
    bootsWithTheRebind = assay.eq machine.systemd.services.nix-daemon-listen.environment.NIX_DAEMON_LISTEN "/nix/var/nix/daemon-socket/socket";
    switchesToTheConformanceSpecialisation = assay.eq (machine.specialisation ? conformance) true;
    # The probes run as an untrusted user.
    aliceIsUntrusted = assay.eq [machine.users.users.alice.isNormalUser (builtins.elem "alice" machine.nix.settings.trusted-users)] [true false];
    # The builder, and the workload the test's own GCs must not delete, are rooted.
    workloadRooted =
      assay.eq (map (d: d.pname or d.name) machine.system.extraDependencies) ["busybox" "conformance.nix" "conformance-builds" "conformance-gc" "conformance-queries"];
  }
