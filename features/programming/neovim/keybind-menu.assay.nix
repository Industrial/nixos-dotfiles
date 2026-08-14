# Colocated suite for features/programming/neovim/keybind-menu.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./keybind-menu.nix;
in
  assay.suite "keybind-menu" {
    mentionsPrograms = assay.eq (builtins.match ".*programs.*" src != null) true;
    mentionsNixvim = assay.eq (builtins.match ".*nixvim.*" src != null) true;
  }
