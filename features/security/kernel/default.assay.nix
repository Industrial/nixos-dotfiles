# Colocated suite: kernel hardening flags.
let
  assay = import ./../../../common/assay/default.nix;
  mod = import ./default.nix {
    config = {};
    lib = (import <nixpkgs> {}).lib;
    pkgs = {};
  };
in
  assay.suite "kernel" {
    lockKernelModules = assay.eq mod.security.lockKernelModules true;
    protectKernelImage = assay.eq mod.security.protectKernelImage true;
  }
