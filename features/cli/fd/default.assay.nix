# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { fd = "fd"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "fd" {
    systemPackages = assay.eq mod.environment.systemPackages [ "fd" ];
  }
