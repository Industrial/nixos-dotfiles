# Colocated suite for features/programming/neovim/buffer-search.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./buffer-search.nix;
in
  assay.suite "buffer-search" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
