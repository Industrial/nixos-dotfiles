# Colocated suite for features/window-manager/gnome/workspace-setup.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./workspace-setup.nix;
in
  assay.suite "workspace-setup" {
    isPackageExpr = assay.eq ((builtins.stringLength src) > 20) true;
  }
