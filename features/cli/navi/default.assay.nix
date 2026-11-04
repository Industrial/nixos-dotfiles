# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {navi = "navi";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "navi" {
    systemPackages = assay.eq mod.environment.systemPackages ["navi"];
  }
