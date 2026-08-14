# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {starship = "starship";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "starship" {
    systemPackages = assay.eq mod.environment.systemPackages ["starship"];
  }
