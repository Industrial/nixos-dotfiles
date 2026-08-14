# Colocated suite for features/programming/neovim/terminal.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./terminal.nix;
in
  assay.suite "terminal" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
