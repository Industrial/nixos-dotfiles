# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { calcurse = "calcurse"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "calcurse" {
    systemPackages = assay.eq mod.environment.systemPackages [ "calcurse" ];
  }
