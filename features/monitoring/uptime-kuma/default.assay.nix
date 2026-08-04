# Colocated suite: uptime-kuma service enable.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    config = {};
    lib = (import <nixpkgs> {}).lib;
    pkgs = {uptime-kuma = "uptime-kuma";};
  };
in
  assay.suite "uptime-kuma" {
    enabled = assay.eq mod.services.uptime-kuma.enable true;
  }
