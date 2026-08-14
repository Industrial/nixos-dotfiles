# Colocated suite for features/programming/neovim/initialize.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./initialize.nix;
in
  assay.suite "initialize" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
