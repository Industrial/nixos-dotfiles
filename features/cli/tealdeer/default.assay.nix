# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {tealdeer = "tealdeer";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "tealdeer" {
    systemPackages = assay.eq mod.environment.systemPackages ["tealdeer"];
  }
