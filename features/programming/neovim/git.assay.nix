# Colocated suite for features/programming/neovim/git.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./git.nix;
in
  assay.suite "git" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
