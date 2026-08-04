# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { "awakened-poe-trade" = "awakened-poe-trade"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "awakened-poe-trade" {
    systemPackages = assay.eq mod.environment.systemPackages [ "awakened-poe-trade" ];
  }
