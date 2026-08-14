# Colocated suite for features/programming/neovim/refactoring.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./refactoring.nix;
in
  assay.suite "refactoring" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
