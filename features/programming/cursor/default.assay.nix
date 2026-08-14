# Colocated suite for features/programming/cursor/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "cursor" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
