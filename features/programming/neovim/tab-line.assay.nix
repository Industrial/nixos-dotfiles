# Colocated suite for features/programming/neovim/tab-line.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./tab-line.nix;
in
  assay.suite "tab-line" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
