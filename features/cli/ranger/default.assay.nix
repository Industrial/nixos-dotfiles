# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { ranger = "ranger"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "ranger" {
    systemPackages = assay.eq mod.environment.systemPackages [ "ranger" ];
  }
