# Colocated suite: systemPackages lands nixstore wrapper.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {
    callPackage = path: args: "nixstore";
  };
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "nixstore" {
    systemPackages = assay.eq mod.environment.systemPackages ["nixstore"];
  }
