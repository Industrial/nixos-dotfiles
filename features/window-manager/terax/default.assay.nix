# Colocated suite: Terax installed on x86_64-linux via callPackage.
let
  assay = import ./../../../common/assay/default.nix;
  lib = (import <nixpkgs> {}).lib;
  pkgs = {
    stdenv = {hostPlatform = {system = "x86_64-linux";};};
    callPackage = path: args: "terax";
    "gdk-pixbuf" = "gdk-pixbuf";
  };
  mod = import ./default.nix {inherit lib pkgs;};
in
  assay.suite "terax" {
    systemPackages = assay.eq mod.environment.systemPackages ["terax"];
  }
