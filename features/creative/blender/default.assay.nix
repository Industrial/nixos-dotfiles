# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {blender = "blender";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "blender" {
    systemPackages = assay.eq mod.environment.systemPackages ["blender"];
  }
