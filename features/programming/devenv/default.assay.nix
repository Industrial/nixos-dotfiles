# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { devenv = "devenv"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "devenv" {
    systemPackages = assay.eq mod.environment.systemPackages [ "devenv" ];
  }
