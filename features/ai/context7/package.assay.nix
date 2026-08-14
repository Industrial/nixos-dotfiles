# Colocated suite for features/ai/context7/package.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./package.nix;
in
  assay.suite "package" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
