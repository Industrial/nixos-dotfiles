# Colocated suite: systemPackages lands nixstore from the assay flake.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {stdenv.hostPlatform.system = "x86_64-linux";};
  inputs = {
    assay.packages.x86_64-linux.nixstore = "nixstore";
  };
  mod = import ./default.nix {inherit pkgs inputs;};
in
  assay.suite "nixstore" {
    systemPackages = assay.eq mod.environment.systemPackages ["nixstore"];
  }
