# Colocated suite for features/nixos/vgen/test.nix — the VM test that prunes a booted
# machine's generations and runs vgc over a pin.
#
# Evaluates the test's node (no VM is booted here; `nix build .#checks.x86_64-linux.vgen-vm`
# runs it), so these claims are about the machine under test: both features as drakkar has
# them, a real EFI boot menu, and the generations the script installs.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) lib;
  pkgs = nixos.flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./test.nix {inherit pkgs;};
  inherit (test.nodes) machine;
in
  assay.suite "vgen-vm-test" {
    named = assay.eq test.name "vm-test-run-vgen-vm";
    # vgen-prune comes in with every vgc run, and vgc no longer prunes itself.
    prunesBeforeVgc = assay.eq machine.systemd.services.vgen-prune.before ["vgc.service"];
    vgcOnlyCollects = assay.eq (lib.hasSuffix "/bin/vgc run" machine.systemd.services.vgc.serviceConfig.ExecStart) true;
    # A real systemd-boot menu on an EFI disk, so the rewrite is the installer's.
    bootsThroughSystemdBoot =
      assay.eq [machine.virtualisation.useBootLoader machine.virtualisation.useEFIBoot machine.boot.loader.systemd-boot.enable] [true true true];
    # The four generations the script sets beside the booted one.
    fourMoreGenerations = assay.eq (builtins.attrNames machine.specialisation) ["g2" "g3" "g4" "g5"];
  }
