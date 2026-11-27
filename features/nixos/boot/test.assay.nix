# Colocated suite for features/nixos/boot/test.nix, the lanzaboote reboot/rollback VM test
# as comin deploys it on muninn (test-vdeploy.assay.nix covers vdeploy on drakkar).
#
# Evaluates the test's node and its Secure Boot generation (no VM is booted here;
# `nix build .#checks.x86_64-linux.lanzaboote-vm` runs it), so these claims are about
# what the test exercises: a real firmware -> bootloader boot, generation 1 on the
# Python installer, generation 2 on lanzaboote, and generation 2 present in the image.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inherit (nixos) flakeInputs;
  pkgs = flakeInputs.nixpkgs.legacyPackages.x86_64-linux;

  test = import ./test.nix {
    inherit pkgs;
    inputs = flakeInputs;
  };
  inherit (test.nodes) machine;
  secureBoot = builtins.head machine.system.extraDependencies;
in
  assay.suite "lanzaboote-vm-test" {
    named = assay.eq test.name "vm-test-run-lanzaboote-vm";
    # Through OVMF and the ESP, never direct kernel boot, or a reboot proves nothing.
    bootsThroughFirmware = assay.eq [machine.virtualisation.useBootLoader machine.virtualisation.useEFIBoot machine.virtualisation.directBoot.enable] [true true false];
    generationOneIsPythonInstaller = assay.eq [machine.boot.loader.systemd-boot.enable machine.boot.lanzaboote.enable] [true false];
    generationOneHasSbctl = assay.eq (nixos.hasPackage machine "sbctl") true;
    # muninn's hardening on the machine under test: the STIG test-host profile and the
    # daemon restricted to @wheel, so the non-root checks are the host's.
    muninnStigTestHost = assay.eq machine.security.stig.profile "test-host";
    restrictedDaemon = assay.eq (builtins.elem "@wheel" machine.nix.settings.allowed-users) true;
    # Two extra dependencies: the Secure Boot generations, manual keys and createKeys.
    generationTwoInImage = assay.eq (builtins.length machine.system.extraDependencies) 2;
    ageForTheBackupCheck = assay.eq (nixos.hasPackage machine "age") true;
    generationTwoIsANixosSystem = assay.eq (pkgs.lib.hasInfix "nixos-system-machine" (toString secureBoot)) true;
  }
