# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { gitbutler = "gitbutler"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "gitbutler" {
    systemPackages = assay.eq mod.environment.systemPackages [ "gitbutler" ];
  }
