# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {difftastic = "difftastic";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "difftastic" {
    systemPackages = assay.eq mod.environment.systemPackages ["difftastic"];
  }
