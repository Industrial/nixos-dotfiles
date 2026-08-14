# Colocated suite for features/programming/neovim/quickfix.nix
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./quickfix.nix {};
  src = builtins.readFile ./quickfix.nix;
in
  assay.suite "quickfix" {
    isAttrs = assay.eq (builtins.isAttrs mod) true;
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
