# Colocated suite: kernel hardening flags.
let
  assay = import ./../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (import ${modFile} {
      config = { };
      lib = (import <nixpkgs> {}).lib;
      pkgs = { };
    })
  '';
in
  assay.suite "kernel" {
    lockKernelModules = assay.eq "${mod}.security.lockKernelModules" "true";
    protectKernelImage = assay.eq "${mod}.security.protectKernelImage" "true";
  }
