# Colocated suite for profiles/development.nix
let
  assay = import ./../common/assay/default.nix;
  src = builtins.readFile ./development.nix;
in
  assay.suite "development" {
    hasImports = assay.eq (builtins.match ".*imports.*=.*" src != null) true;
  }
