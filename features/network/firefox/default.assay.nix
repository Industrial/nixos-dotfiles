# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { librewolf = "librewolf"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "firefox" {
    systemPackages = assay.eq mod.environment.systemPackages [ "librewolf" ];
  }
