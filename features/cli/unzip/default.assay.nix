# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { unzip = "unzip"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "unzip" {
    systemPackages = assay.eq mod.environment.systemPackages [ "unzip" ];
  }
