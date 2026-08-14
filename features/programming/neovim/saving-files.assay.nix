# Colocated suite for features/programming/neovim/saving-files.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./saving-files.nix;
in
  assay.suite "saving-files" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
