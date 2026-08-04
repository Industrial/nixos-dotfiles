# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {inkscape = "inkscape";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "inkscape" {
    systemPackages = assay.eq mod.environment.systemPackages ["inkscape"];
  }
