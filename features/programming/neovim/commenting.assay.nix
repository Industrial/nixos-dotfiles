# Colocated suite for features/programming/neovim/commenting.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./commenting.nix;
in
  assay.suite "commenting" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
