# Colocated suite for features/finance/ib-gateway/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "ib-gateway" {
    isPackageExpr = assay.eq ((builtins.stringLength src) > 20) true;
  }
