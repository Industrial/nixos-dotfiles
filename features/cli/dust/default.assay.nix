# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { dust = "dust"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "dust" {
    systemPackages = assay.eq mod.environment.systemPackages [ "dust" ];
  }
