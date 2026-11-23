# Assay: features/nixos/etc-overlay/node.nix, the host node the VM tests share. Pins how far
# it is from the host (disko only, plus the qemu-vm adjustments), for drakkar (the default)
# and for a host named explicitly, and the one package set that keeps each check inside
# CI's eval budget. The evaluated nodes themselves are ./test.assay.nix's and
# ./test-live-switch.assay.nix's.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  inputs = nixos.flakeInputs;
  drakkar = import ./node.nix {inherit inputs;};
  mimir = import ./node.nix {
    inherit inputs;
    hostname = "mimir";
  };
in
  assay.suite "etc-overlay-node" {
    drakkarByDefault = assay.eq [drakkar.hostname drakkar.settings.hostname] ["drakkar" "drakkar"];
    drakkarsOwnConfig = assay.eq (builtins.elem ../../../hosts/drakkar/configuration.nix drakkar.module.imports) true;
    onlyDiskoLeftOut = assay.eq drakkar.module.disabledModules [../../../hosts/drakkar/disko.nix];
    # Another host: its own configuration, its own disko left out, its own settings.
    mimirsOwnConfig = assay.eq (builtins.elem ../../../hosts/mimir/configuration.nix mimir.module.imports) true;
    mimirOnlyDiskoLeftOut = assay.eq mimir.module.disabledModules [../../../hosts/mimir/disko.nix];
    mimirSettings = assay.eq mimir.settings.hostname "mimir";
    nodeMayConfigureNixpkgs = assay.eq drakkar.node.pkgsReadOnly false;
    onePackageSet = assay.eq (drakkar.module.nixpkgs.config.content or null) {};
    # The resume device lives in disko's LUKS container (huginn), so the VM has none.
    noResumeDevice = assay.eq (drakkar.module.boot.resumeDevice.content or null) "";
    # The nodes start without the feature, whatever the host enables.
    withoutTheFeature = assay.eq [(drakkar.module.features.nixos.etc-overlay.enable.priority or null) (drakkar.module.features.nixos.etc-overlay.enable.content or null)] [60 false];
    vmSize = assay.eq [drakkar.module.virtualisation.cores drakkar.module.virtualisation.memorySize] [4 6144];
  }
