# Colocated suite for features/nixos/boot/test-vdeploy-muninn.nix, muninn's lanzaboote gate
# under vdeploy with createKeys (GH-184, GH-343). Evaluates the test's node and its Secure
# Boot generation; no VM is booted here
# (`nix build .#checks.x86_64-linux.lanzaboote-vdeploy-vm-muninn` runs it).
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) flakeInputs;
  pkgs = flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./test-vdeploy-muninn.nix {
    inherit pkgs;
    inputs = flakeInputs;
  };
  inherit (test.nodes) machine;
  secureBoot = builtins.head machine.system.extraDependencies;
in
  assay.suite "lanzaboote-vdeploy-vm-muninn-test" {
    named = assay.eq test.name "vm-test-run-lanzaboote-vdeploy-vm-muninn";
    bootsThroughFirmware = assay.eq [machine.virtualisation.useBootLoader machine.virtualisation.useEFIBoot machine.virtualisation.directBoot.enable] [true true false];
    # The real vdeploy, in deploy mode: test, vhealth, then the system profile and `boot`.
    vdeployDeploys = assay.eq machine.features.nix.vdeploy.mode "deploy";
    vdeployApplyWrapperInstalled = assay.eq (nixos.hasPackage machine "vdeploy-apply") true;
    # muninn's hardening on the machine under test.
    muninnStigTestHost = assay.eq machine.security.stig.profile "test-host";
    etcOnTheOverlay = assay.eq [machine.system.etc.overlay.enable machine.system.etc.overlay.mutable] [true true];
    restrictedDaemon = assay.eq (builtins.elem "@wheel" machine.nix.settings.allowed-users) true;
    generationOneIsPythonInstaller = assay.eq [machine.boot.loader.systemd-boot.enable machine.boot.lanzaboote.enable] [true false];
    ageForTheBackupCheck = assay.eq (nixos.hasPackage machine "age") true;
    # Exactly one extra dependency: muninn's Secure Boot generation, createKeys on.
    generationTwoInImage = assay.eq (builtins.length machine.system.extraDependencies) 1;
    generationTwoIsANixosSystem = assay.eq (pkgs.lib.hasInfix "nixos-system-machine" (toString secureBoot)) true;
  }
