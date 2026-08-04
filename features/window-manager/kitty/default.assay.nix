# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { kitty = "kitty"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "kitty" {
    systemPackages = assay.eq mod.environment.systemPackages [ "kitty" ];
  }
