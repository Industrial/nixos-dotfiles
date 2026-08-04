# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { chromium = "chromium"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "chromium" {
    systemPackages = assay.eq mod.environment.systemPackages [ "chromium" ];
  }
