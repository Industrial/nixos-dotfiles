# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {lsof = "lsof";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "lsof" {
    systemPackages = assay.eq mod.environment.systemPackages ["lsof"];
  }
