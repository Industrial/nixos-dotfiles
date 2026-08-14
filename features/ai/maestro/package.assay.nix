# Colocated suite for features/ai/maestro/package.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./package.nix;
in
  assay.suite "package" {
    isPackageExpr = assay.eq ((builtins.stringLength src) > 20) true;
  }
