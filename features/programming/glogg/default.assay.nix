# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { glogg = "glogg"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "glogg" {
    systemPackages = assay.eq mod.environment.systemPackages [ "glogg" ];
  }
