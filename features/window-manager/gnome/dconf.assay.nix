# Colocated suite for features/window-manager/gnome/dconf.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./dconf.nix;
in
  assay.suite "dconf" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
