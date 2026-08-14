# Colocated suite for features/programming/neovim/environment.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./environment.nix;
in
  assay.suite "environment" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
