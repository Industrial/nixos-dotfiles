# Colocated suite for features/programming/neovim/color-scheme.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./color-scheme.nix;
in
  assay.suite "color-scheme" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
