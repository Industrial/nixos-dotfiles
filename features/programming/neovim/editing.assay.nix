# Colocated suite for features/programming/neovim/editing.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./editing.nix;
in
  assay.suite "editing" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
