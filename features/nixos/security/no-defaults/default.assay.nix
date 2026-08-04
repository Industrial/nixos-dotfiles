# Colocated suite: environment.defaultPackages is mkForce [].
let
  assay = import ../../../../common/assay/default.nix;
  modFile = toString ./default.nix;
  mod = ''
    (import ${modFile} {
      lib = (import <nixpkgs> {}).lib;
    }).environment.defaultPackages
  '';
in
  assay.suite "no-defaults" {
    forcedEmpty = assay.eq "${mod}.content" "[]";
    isOverride = assay.eq "${mod}._type" "\"override\"";
    forcePriority = assay.eq "${mod}.priority" "50";
  }
