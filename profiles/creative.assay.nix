# Colocated suite for profiles/creative.nix
let
  assay = import ./../common/assay/default.nix;
  src = builtins.readFile ./creative.nix;
in
  assay.suite "creative" {
    hasImports = assay.eq (builtins.match ".*imports.*=.*" src != null) true;
  }
