# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { obsidian = "obsidian"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "obsidian" {
    systemPackages = assay.eq mod.environment.systemPackages [ "obsidian" ];
  }
