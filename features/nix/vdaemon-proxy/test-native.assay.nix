# Colocated suite for features/nix/vdaemon-proxy/test-native.nix — the VM test that
# switches native answering into and out of a running system.
#
# Evaluates the test's node (no VM is booted here): no proxy at boot, the rebind oneshot
# every host carries, the native specialisation it switches to, and an untrusted user.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./test-native.nix {inherit pkgs;};
  inherit (test.nodes) machine;
in
  assay.suite "vdaemon-proxy-native-vm-test" {
    named = assay.eq test.name "vm-test-run-vdaemon-proxy-native";
    # Rule 17: the proxy arrives by a live switch, not at boot.
    bootsWithoutTheProxy = assay.eq (machine.systemd.sockets ? vdaemon-proxy) false;
    bootsWithTheRebind = assay.eq machine.systemd.services.nix-daemon-listen.environment.NIX_DAEMON_LISTEN "/nix/var/nix/daemon-socket/socket";
    switchesToTheNativeSpecialisation = assay.eq (machine.specialisation ? native) true;
    aliceIsUntrusted = assay.eq [machine.users.users.alice.isNormalUser (builtins.elem "alice" machine.nix.settings.trusted-users)] [true false];
    workloadRooted =
      assay.eq (map (d: d.pname or d.name) machine.system.extraDependencies) ["busybox" "native.nix" "native-queries" "native-builds" "native-gc"];
  }
