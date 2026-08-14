# Colocated suite: systemPackages lands nixdrv from the assay flake.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {system = "x86_64-linux";};
  inputs = {
    assay.packages.x86_64-linux.nixdrv = "nixdrv";
  };
  mod = import ./default.nix {inherit pkgs inputs;};
in
  assay.suite "nixdrv" {
    systemPackages = assay.eq mod.environment.systemPackages ["nixdrv"];
  }
