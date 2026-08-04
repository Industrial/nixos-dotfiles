# Colocated suite: programs.gamemode.enable.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { };
  mod = import ./default.nix { inherit pkgs; };
in
  assay.suite "lutris" {
    enabled = assay.eq mod.programs.gamemode.enable true;
  }
