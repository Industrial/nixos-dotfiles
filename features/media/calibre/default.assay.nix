# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { calibre = "calibre"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "calibre" {
    systemPackages = assay.eq mod.environment.systemPackages [ "calibre" ];
  }
