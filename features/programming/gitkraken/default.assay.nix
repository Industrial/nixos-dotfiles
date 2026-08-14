# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {gitkraken = "gitkraken";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "gitkraken" {
    systemPackages = assay.eq mod.environment.systemPackages ["gitkraken"];
  }
