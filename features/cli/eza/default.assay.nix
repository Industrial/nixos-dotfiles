# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { eza = "eza"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "eza" {
    systemPackages = assay.eq mod.environment.systemPackages [ "eza" ];
  }
