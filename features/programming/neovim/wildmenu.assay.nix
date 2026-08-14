# Colocated suite for features/programming/neovim/wildmenu.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./wildmenu.nix;
in
  assay.suite "wildmenu" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
