# Colocated suite: apparmor enable.
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
  assay.suite "apparmor" {
    enabled = assay.eq "${mod}.security.apparmor.enable" "true";
  }
