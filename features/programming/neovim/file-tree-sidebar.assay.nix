# Colocated suite for features/programming/neovim/file-tree-sidebar.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./file-tree-sidebar.nix;
in
  assay.suite "file-tree-sidebar" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
