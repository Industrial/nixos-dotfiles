# Colocated suite for features/programming/neovim/testing.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./testing.nix;
in
  assay.suite "testing" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
