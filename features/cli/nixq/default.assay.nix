# Colocated suite: systemPackages lands nixq from the assay flake.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {stdenv.hostPlatform.system = "x86_64-linux";};
  inputs = {
    assay.packages.x86_64-linux.nixq = "nixq";
  };
  mod = import ./default.nix {inherit pkgs inputs;};
in
  assay.suite "nixq" {
    systemPackages = assay.eq mod.environment.systemPackages ["nixq"];
  }
