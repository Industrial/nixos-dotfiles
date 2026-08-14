# Colocated suite: systemPackages lands nix-hash wrapper.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {
    callPackage = path: args: "nix-hash";
  };
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "nix-hash" {
    systemPackages = assay.eq mod.environment.systemPackages ["nix-hash"];
  }
