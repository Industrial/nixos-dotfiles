# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {discord = "discord";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "discord" {
    systemPackages = assay.eq mod.environment.systemPackages ["discord"];
  }
