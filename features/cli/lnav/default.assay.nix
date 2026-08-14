# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {lnav = "lnav";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "lnav" {
    systemPackages = assay.eq mod.environment.systemPackages ["lnav"];
  }
