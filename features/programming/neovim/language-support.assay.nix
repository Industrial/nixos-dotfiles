# Colocated suite for features/programming/neovim/language-support.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./language-support.nix;
in
  assay.suite "language-support" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
