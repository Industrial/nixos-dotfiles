# Colocated suite for common/assay/default.nix
let
  assay = import ./../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "assay" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
