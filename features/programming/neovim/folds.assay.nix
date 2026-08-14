# Colocated suite for features/programming/neovim/folds.nix
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./folds.nix {};
  src = builtins.readFile ./folds.nix;
in
  assay.suite "folds" {
    isAttrs = assay.eq (builtins.isAttrs mod) true;
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
