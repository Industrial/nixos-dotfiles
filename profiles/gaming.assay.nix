# Colocated suite for profiles/gaming.nix
let
  assay = import ./../common/assay/default.nix;
  src = builtins.readFile ./gaming.nix;
in
  assay.suite "gaming" {
    hasImports = assay.eq (builtins.match ".*imports.*=.*" src != null) true;
  }
