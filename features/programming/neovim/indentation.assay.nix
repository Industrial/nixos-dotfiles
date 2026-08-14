# Colocated suite for features/programming/neovim/indentation.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./indentation.nix;
in
  assay.suite "indentation" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
