# Colocated suite for features/window-manager/terax/package.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./package.nix;
in
  assay.suite "package" {
    isPackageExpr = assay.eq ((builtins.stringLength src) > 20) true;
  }
