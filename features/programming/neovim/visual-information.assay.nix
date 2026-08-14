# Colocated suite for features/programming/neovim/visual-information.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./visual-information.nix;
in
  assay.suite "visual-information" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
