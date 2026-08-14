# Colocated suite for features/programming/neovim/searching.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./searching.nix;
in
  assay.suite "searching" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
