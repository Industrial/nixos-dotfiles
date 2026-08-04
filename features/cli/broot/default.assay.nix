# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {broot = "broot";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "broot" {
    systemPackages = assay.eq mod.environment.systemPackages ["broot"];
  }
