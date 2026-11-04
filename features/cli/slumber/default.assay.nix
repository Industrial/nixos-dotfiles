# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {slumber = "slumber";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "slumber" {
    systemPackages = assay.eq mod.environment.systemPackages ["slumber"];
  }
