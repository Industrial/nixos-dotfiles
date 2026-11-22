# Colocated suite for features/nixos/etc-overlay/test-live-switch.nix, the feature's gate.
# Evaluates the test's node (no VM is booted here;
# `nix build .#checks.x86_64-linux.etc-overlay-live-switch` runs it), so these claims pin
# what the gate starts from and what it switches into.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inputs = nixos.flakeInputs;
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  inherit (nixos) lib;

  test = import ./test-live-switch.nix {inherit pkgs inputs;};
  base = test.nodes.machine;
  withOverlay = base.gh185.withOverlay.config;
in
  assay.suite "etc-overlay-live-switch-test" {
    named = assay.eq test.name "vm-test-run-etc-overlay-live-switch";
    # Boots without the feature, and switches into the feature, not the bare option.
    bootsWithoutTheFeature = assay.eq [base.features.nixos.etc-overlay.enable base.system.etc.overlay.enable] [false false];
    entersTheFeature =
      assay.eq [withOverlay.features.nixos.etc-overlay.enable withOverlay.system.etc.overlay.enable withOverlay.system.etc.overlay.mutable] [true true true];
    # Leaving has to carry out, so the base generation holds the exit half.
    baseCarriesOut = assay.eq (base.system.activationScripts ? etcOverlayCarryOut) true;
    # Switchable without specialisations, and the overlay generation's VM is in the image.
    switchable = assay.eq [base.system.switch.enable withOverlay.system.switch.enable] [true true];
    overlayVmInTheStore =
      assay.eq (map (d: d.name) base.system.extraDependencies) [withOverlay.system.build.vm.name];
    noSelfReference = assay.eq withOverlay.system.extraDependencies [];
    # Two evaluations of drakkar: no specialisations on top of the extension.
    noSpecialisations = assay.eq [base.specialisation withOverlay.specialisation] [{} {}];
    # vhealth runs as its own user, the identity the gate checks it with.
    vhealthUser = assay.eq (base.users.users ? vhealth) true;
  }
