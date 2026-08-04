# Colocated suite: systemPackages lands nix1-hash wrapper.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {
    callPackage = path: args: "nix1-hash";
  };
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "nix1-hash" {
    systemPackages = assay.eq mod.environment.systemPackages ["nix1-hash"];
  }
