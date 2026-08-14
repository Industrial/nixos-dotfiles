# Colocated suite for features/nixos/graphics/amd.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./amd.nix;
in
  assay.suite "amd" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
