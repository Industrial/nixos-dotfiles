# Colocated suite for features/programming/neovim/status-line.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./status-line.nix;
in
  assay.suite "status-line" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
