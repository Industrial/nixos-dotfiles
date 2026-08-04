# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { "wowup-cf" = "wowup-cf"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "wowup" {
    systemPackages = assay.eq mod.environment.systemPackages [ "wowup-cf" ];
  }
