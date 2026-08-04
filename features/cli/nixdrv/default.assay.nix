# Colocated suite: systemPackages lands nixdrv wrapper.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {
    callPackage = path: args: "nixdrv";
  };
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "nixdrv" {
    systemPackages = assay.eq mod.environment.systemPackages ["nixdrv"];
  }
