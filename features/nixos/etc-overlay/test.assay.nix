# Colocated suite for features/nixos/etc-overlay/test.nix: the GH-185 measurement of
# drakkar's /etc under setup-etc.pl against system.etc.overlay.
#
# Evaluates the test's node in both variants (no VM is booted here;
# `nix build .#checks.x86_64-linux.etc-overlay-{stock,on}` runs them), so these claims pin
# what is being measured: drakkar's full configuration minus disko only, the /etc
# implementation of each variant, and the specialisations the switches go between.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inputs = nixos.flakeInputs;
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;

  testFor = overlay: import ./test.nix {inherit pkgs inputs overlay;};
  stockTest = testFor false;
  onTest = testFor true;
  stock = stockTest.nodes.machine;
  on = onTest.nodes.machine;
in
  assay.suite "etc-overlay-vm-test" {
    named = assay.eq [stockTest.name onTest.name] ["vm-test-run-etc-overlay-stock" "vm-test-run-etc-overlay-on"];
    isDrakkar = assay.eq stock.networking.hostName "drakkar";
    # Only disko is left out: its LUKS root has no place in a VM.
    noLuksFromDisko = assay.eq stock.boot.initrd.luks.devices {};
    # The Voltaic tools run as on the host; nothing else is switched off.
    fullHostFeatures = assay.eq [stock.features.nix.vverify.enable stock.features.nixos.vgc.enable] [true true];
    stockUsesSetupEtc = assay.eq stock.system.etc.overlay.enable false;
    onUsesTheOverlay = assay.eq [on.system.etc.overlay.enable on.system.etc.overlay.mutable] [true true];
    # The switches go base <-> alt, which differ by one /etc file, so the overlay remounts.
    altAddsTheMarker = assay.eq (on.specialisation.alt.configuration.environment.etc ? "gh185-marker") true;
    baseHasNoMarker = assay.eq (on.environment.etc ? "gh185-marker") false;
    # Stock only: the live switch into the overlay that shows what the old /etc held.
    stockCanSwitchIntoTheOverlay =
      assay.eq stock.specialisation.overlay.configuration.system.etc.overlay.enable true;
    onHasNoOverlaySpecialisation = assay.eq (on.specialisation ? overlay) false;
  }
