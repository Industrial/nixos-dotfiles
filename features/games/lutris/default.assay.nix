# Colocated suite: programs.gamemode.enable.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  enable = ''
(    let
      pkgs = { };
      mod = import ${modFile} { inherit pkgs; };
    in mod.programs.gamemode.enable)
'';
in
  assay.suite "lutris" {
    enabled = assay.eq enable "true";
  }
