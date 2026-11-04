# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {atuin = "atuin";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "atuin" {
    systemPackages = assay.eq mod.environment.systemPackages ["atuin"];
  }
