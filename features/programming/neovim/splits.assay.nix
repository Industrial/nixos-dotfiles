# Colocated suite for features/programming/neovim/splits.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./splits.nix;
in
  assay.suite "splits" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
