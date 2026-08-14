# Colocated suite for features/nixos/auto-update/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "auto-update" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
