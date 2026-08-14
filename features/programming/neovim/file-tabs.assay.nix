# Colocated suite for features/programming/neovim/file-tabs.nix
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./file-tabs.nix {};
  src = builtins.readFile ./file-tabs.nix;
in
  assay.suite "file-tabs" {
    isAttrs = assay.eq (builtins.isAttrs mod) true;
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
