# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {dysk = "dysk";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "dysk" {
    systemPackages = assay.eq mod.environment.systemPackages ["dysk"];
  }
