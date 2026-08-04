# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {"nix-tree" = "nix-tree";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "nix-tree" {
    systemPackages = assay.eq mod.environment.systemPackages ["nix-tree"];
  }
