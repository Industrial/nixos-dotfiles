# Colocated suite for features/programming/neovim/debug-adapter-protocol.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./debug-adapter-protocol.nix;
in
  assay.suite "debug-adapter-protocol" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
