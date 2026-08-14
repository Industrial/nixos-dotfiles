# Colocated suite for features/programming/neovim/undo-files.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./undo-files.nix;
in
  assay.suite "undo-files" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
