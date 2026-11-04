# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {nvd = "nvd";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "nvd" {
    systemPackages = assay.eq mod.environment.systemPackages ["nvd"];
  }
