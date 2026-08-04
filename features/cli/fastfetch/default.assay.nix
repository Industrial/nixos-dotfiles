# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { fastfetch = "fastfetch"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "fastfetch" {
    systemPackages = assay.eq mod.environment.systemPackages [ "fastfetch" ];
  }
