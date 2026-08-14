# Colocated suite for profiles/base.nix
let
  assay = import ./../common/assay/default.nix;
  src = builtins.readFile ./base.nix;
in
  assay.suite "base" {
    hasImports = assay.eq (builtins.match ".*imports.*=.*" src != null) true;
  }
