# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {fractal = "fractal";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "fractal" {
    systemPackages = assay.eq mod.environment.systemPackages ["fractal"];
  }
