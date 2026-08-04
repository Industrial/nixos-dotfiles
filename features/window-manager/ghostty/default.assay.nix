# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { ghostty = "ghostty"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "ghostty" {
    systemPackages = assay.eq mod.environment.systemPackages [ "ghostty" ];
  }
