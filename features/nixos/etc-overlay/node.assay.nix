# Assay: features/nixos/etc-overlay/node.nix, the drakkar node the VM tests share. Pins
# how far it is from the host (disko only, plus the qemu-vm adjustments) and the one
# package set that keeps each check inside CI's eval budget. The evaluated node itself is
# ./test.assay.nix's.
let
  assay = import ../../../common/assay/default.nix;
  nixos = import ../../../common/assay/nixos.nix;
  drakkar = import ./node.nix {inputs = nixos.flakeInputs;};
in
  assay.suite "etc-overlay-node" {
    drakkarsOwnConfig = assay.eq (builtins.elem ../../../hosts/drakkar/configuration.nix drakkar.module.imports) true;
    onlyDiskoLeftOut = assay.eq drakkar.module.disabledModules [../../../hosts/drakkar/disko.nix];
    nodeMayConfigureNixpkgs = assay.eq drakkar.node.pkgsReadOnly false;
    onePackageSet = assay.eq (drakkar.module.nixpkgs.config.content or null) {};
    vmSize = assay.eq [drakkar.module.virtualisation.cores drakkar.module.virtualisation.memorySize] [4 6144];
  }
