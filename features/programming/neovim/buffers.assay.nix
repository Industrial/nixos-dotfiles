# Colocated suite for features/programming/neovim/buffers.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./buffers.nix;
in
  assay.suite "buffers" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
