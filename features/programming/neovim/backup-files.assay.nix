# Colocated suite for features/programming/neovim/backup-files.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./backup-files.nix;
in
  assay.suite "backup-files" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
