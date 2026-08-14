# Colocated suite for features/window-manager/hyprland/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "hyprland" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
