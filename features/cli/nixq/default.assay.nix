# Colocated suite: systemPackages lands nixq wrapper.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {
    callPackage = path: args: "nixq";
  };
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "nixq" {
    systemPackages = assay.eq mod.environment.systemPackages ["nixq"];
  }
