# Colocated suite: programs.lazygit.enable.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  enable = ''
(    let
      pkgs = { };
      mod = import ${modFile} { inherit pkgs; };
    in mod.programs.lazygit.enable)
'';
in
  assay.suite "lazygit" {
    enabled = assay.eq enable "true";
  }
