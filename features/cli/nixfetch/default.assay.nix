# Colocated suite: systemPackages lands nixfetch from the assay flake.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {stdenv.hostPlatform.system = "x86_64-linux";};
  inputs = {
    assay.packages.x86_64-linux.nixfetch = "nixfetch";
  };
  mod = import ./default.nix {inherit pkgs inputs;};
in
  assay.suite "nixfetch" {
    systemPackages = assay.eq mod.environment.systemPackages ["nixfetch"];
  }
