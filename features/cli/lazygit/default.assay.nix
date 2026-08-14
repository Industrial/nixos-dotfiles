# Colocated suite: programs.lazygit.enable.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "lazygit" {
    enabled = assay.eq mod.programs.lazygit.enable true;
  }
