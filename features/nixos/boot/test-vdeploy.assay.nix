# Colocated suite for features/nixos/boot/test-vdeploy.nix, the lanzaboote VM test that runs
# the real vdeploy apply on drakkar's profile layout (GH-184). Evaluates the test's node and
# its Secure Boot generation; no VM is booted here
# (`nix build .#checks.x86_64-linux.lanzaboote-vdeploy-vm` runs it).
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) flakeInputs;
  pkgs = flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./test-vdeploy.nix {
    inherit pkgs;
    inputs = flakeInputs;
  };
  inherit (test.nodes) machine;
  secureBoot = builtins.head machine.system.extraDependencies;
in
  assay.suite "lanzaboote-vdeploy-vm-test" {
    named = assay.eq test.name "vm-test-run-lanzaboote-vdeploy-vm";
    # Through OVMF and the ESP, never direct kernel boot, or a reboot proves nothing.
    bootsThroughFirmware = assay.eq [machine.virtualisation.useBootLoader machine.virtualisation.useEFIBoot machine.virtualisation.directBoot.enable] [true true false];
    # The real vdeploy, in deploy mode: test, vhealth, then the system profile and `boot`.
    vdeployDeploys = assay.eq machine.features.nix.vdeploy.mode "deploy";
    vdeployApplyWrapperInstalled = assay.eq (nixos.hasPackage machine "vdeploy-apply") true;
    # drakkar's daemon restriction, which the non-root checks go through.
    restrictedDaemon = assay.eq (builtins.elem "@wheel" machine.nix.settings.allowed-users) true;
    healthProbe = assay.eq (builtins.hasAttr "web" machine.features.nix.vhealth.probes) true;
    generationOneIsPythonInstaller = assay.eq [machine.boot.loader.systemd-boot.enable machine.boot.lanzaboote.enable] [true false];
    generationOneHasSbctl = assay.eq (nixos.hasPackage machine "sbctl") true;
    # Exactly one extra dependency: the Secure Boot generation's toplevel.
    generationTwoInImage = assay.eq (builtins.length machine.system.extraDependencies) 1;
    generationTwoIsANixosSystem = assay.eq (pkgs.lib.hasInfix "nixos-system-machine" (toString secureBoot)) true;
  }
