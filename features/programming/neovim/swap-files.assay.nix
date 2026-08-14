# Colocated suite for features/programming/neovim/swap-files.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./swap-files.nix;
in
  assay.suite "swap-files" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
