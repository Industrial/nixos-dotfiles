# Colocated suite for features/nix/vdeploy/test-wake.nix, the wake VM test (GH-246). Evaluates
# the test's nodes, so the claims are about the machines under test; no VM is booted here
# (`nix build .#checks.x86_64-linux.vdeploy-wake-vm` runs it).
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (pkgs) lib;

  test = import ./test-wake.nix {inherit pkgs;};
  t = test.nodes.target;
  spec = name: t.specialisation.${name}.configuration;
  exec = c: c.systemd.services.vdeploy.serviceConfig.ExecStart;
in
  assay.suite "vdeploy-wake-vm-test" {
    named = assay.eq test.name "vm-test-run-vdeploy-wake-vm";
    # Boots WITHOUT wake support; the `wake` specialisation switches it in live.
    bootsWithoutWake = assay.eq [(lib.hasInfix "--wake-fifo" (exec t)) (lib.hasInfix "--wake-fifo" (exec (spec "wake")))] [false true];
    # Hardened as mimir is (STIG base-safe: auditd is one of its controls), restricted daemon.
    stigBaseSafe = assay.eq t.security.auditd.enable true;
    restrictedDaemon = assay.eq (builtins.elem "@wheel" t.nix.settings.allowed-users) true;
    # Deploy mode, and an interval long enough that only a wake polls during the test.
    deployModeLongInterval = assay.eq [t.features.nix.vdeploy.mode t.features.nix.vdeploy.interval] ["deploy" "1h"];
    # The operator wakes; bob does not.
    operatorIsAlice = assay.eq (spec "wake").users.groups.vdeploy-wake.members ["alice"];
  }
