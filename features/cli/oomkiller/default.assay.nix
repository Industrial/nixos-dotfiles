# Colocated suite for features/cli/oomkiller/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "oomkiller" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
