# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {foliate = "foliate";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "foliate" {
    systemPackages = assay.eq mod.environment.systemPackages ["foliate"];
  }
