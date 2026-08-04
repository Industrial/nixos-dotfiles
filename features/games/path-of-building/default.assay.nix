# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { "rusty-path-of-building" = "rusty-path-of-building"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "path-of-building" {
    systemPackages = assay.eq mod.environment.systemPackages [ "rusty-path-of-building" ];
  }
