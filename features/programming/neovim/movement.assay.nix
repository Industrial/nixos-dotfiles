# Colocated suite for features/programming/neovim/movement.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./movement.nix;
in
  assay.suite "movement" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
