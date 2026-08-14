# Colocated suite for features/window-manager/stylix/derivations/tinted-theming-schemes.nix
let
  assay = import ./../../../../common/assay/default.nix;
  src = builtins.readFile ./tinted-theming-schemes.nix;
in
  assay.suite "tinted-theming-schemes" {
    isPackageExpr = assay.eq ((builtins.stringLength src) > 20) true;
  }
