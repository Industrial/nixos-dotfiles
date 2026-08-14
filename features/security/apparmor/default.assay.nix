# Colocated suite: apparmor enable.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    config = {};
    lib = (import <nixpkgs> {}).lib;
    pkgs = {};
  };
in
  assay.suite "apparmor" {
    enabled = assay.eq mod.security.apparmor.enable true;
  }
