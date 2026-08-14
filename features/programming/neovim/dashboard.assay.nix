# Colocated suite for features/programming/neovim/dashboard.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./dashboard.nix;
in
  assay.suite "dashboard" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
