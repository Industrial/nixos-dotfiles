# Colocated suite for common/assert.nix
let
  assay = import ./../common/assay/default.nix;
  src = builtins.readFile ./assert.nix;
in
  assay.suite "assert" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
