# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {nvtopPackages = {full = "nvtopPackages.full";};};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "nvtop" {
    systemPackages = assay.eq mod.environment.systemPackages ["nvtopPackages.full"];
  }
