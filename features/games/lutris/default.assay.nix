# Colocated suite: programs.gamemode.enable (deliberately off — see default.nix).
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "lutris" {
    gamemodeDisabled = assay.eq mod.programs.gamemode.enable false;
  }
