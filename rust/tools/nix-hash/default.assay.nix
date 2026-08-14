# Colocated suite for rust/tools/nix-hash/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "nix-hash" {
    isPackageExpr = assay.eq ((builtins.stringLength src) > 20) true;
  }
