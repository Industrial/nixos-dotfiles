# Colocated suite for features/programming/neovim/library.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./library.nix;
in
  assay.suite "library" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
