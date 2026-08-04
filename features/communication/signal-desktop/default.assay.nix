# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { "signal-desktop" = "signal-desktop"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "signal-desktop" {
    systemPackages = assay.eq mod.environment.systemPackages [ "signal-desktop" ];
  }
