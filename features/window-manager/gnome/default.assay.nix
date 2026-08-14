# Colocated suite for features/window-manager/gnome/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "gnome" {
    hasImports = assay.eq (builtins.match ".*imports.*=.*" src != null) true;
  }
