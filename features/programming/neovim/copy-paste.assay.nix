# Colocated suite for features/programming/neovim/copy-paste.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./copy-paste.nix;
in
  assay.suite "copy-paste" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
