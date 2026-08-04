# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {gping = "gping";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "gping" {
    systemPackages = assay.eq mod.environment.systemPackages ["gping"];
  }
