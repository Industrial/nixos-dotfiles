# Colocated suite for features/nixos/boot/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "boot" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
