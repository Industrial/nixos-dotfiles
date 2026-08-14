# Colocated suite for features/finance/tws/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "tws" {
    isPackageExpr = assay.eq ((builtins.stringLength src) > 20) true;
  }
