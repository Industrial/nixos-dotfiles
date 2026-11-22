# Colocated suite for features/nixos/etc-overlay's VM tests (GH-185): ./test.nix (the
# measurement of setup-etc.pl against the overlay) and ./test-live-switch.nix (the gate:
# the feature switched into and out of, live and cold, with the state kept).
#
# Evaluates the tests' nodes (no VM is booted here;
# `nix build .#checks.x86_64-linux.etc-overlay-{stock,on,live-switch}` runs them), so
# these claims pin what is under test: drakkar's full configuration minus disko only, the
# /etc implementation of each variant, and that every check evaluates drakkar twice.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inputs = nixos.flakeInputs;
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;

  testFor = variant: import ./test.nix {inherit pkgs inputs variant;};
  stockTest = testFor "stock";
  onTest = testFor "on";
  liveTest = import ./test-live-switch.nix {inherit pkgs inputs;};
  stock = stockTest.nodes.machine;
  on = onTest.nodes.machine;
  live = liveTest.nodes.machine;
  liveIn = live.gh185.withOverlay.config;
in
  assay.suite "etc-overlay-vm-test" {
    named =
      assay.eq [stockTest.name onTest.name liveTest.name]
      ["vm-test-run-etc-overlay-stock" "vm-test-run-etc-overlay-on" "vm-test-run-etc-overlay-live-switch"];
    # Two evaluations of drakkar per check: the node plus one specialisation or extension.
    oneSpecialisationEach =
      assay.eq (map (m: builtins.attrNames m.specialisation) [stock on live]) [["alt"] ["alt"] []];
    # The node and its extensions share drakkar's package set, instantiated once.
    sharesDrakkarPkgs = assay.eq (on.nixpkgs.config == {} && on.nixpkgs.overlays == []) true;
    isDrakkar = assay.eq stock.networking.hostName "drakkar";
    # Only disko is left out: its LUKS root has no place in a VM.
    noLuksFromDisko = assay.eq stock.boot.initrd.luks.devices {};
    # The Voltaic tools run as on the host; nothing else is switched off.
    fullHostFeatures = assay.eq [stock.features.nix.vverify.enable stock.features.nixos.vgc.enable stock.features.nix.vhealth.enable] [true true true];
    stockUsesSetupEtc = assay.eq stock.system.etc.overlay.enable false;
    onUsesTheOverlay = assay.eq [on.system.etc.overlay.enable on.system.etc.overlay.mutable] [true true];
    # The switches go base <-> alt, which differ by one /etc file, so the overlay remounts.
    altAddsTheMarker = assay.eq (on.specialisation.alt.configuration.environment.etc ? "gh185-marker") true;
    baseHasNoMarker = assay.eq (on.environment.etc ? "gh185-marker") false;
    # live-switch boots without the feature and goes into it: the feature, not the bare option.
    liveSwitchBootsWithoutTheFeature =
      assay.eq [live.features.nixos.etc-overlay.enable live.system.etc.overlay.enable] [false false];
    liveSwitchEntersTheFeature =
      assay.eq [liveIn.features.nixos.etc-overlay.enable liveIn.system.etc.overlay.enable liveIn.system.etc.overlay.mutable] [true true true];
  }
