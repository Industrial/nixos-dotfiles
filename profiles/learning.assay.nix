# Colocated suite for profiles/learning.nix
let
  assay = import ./../common/assay/default.nix;
  src = builtins.readFile ./learning.nix;
in
  assay.suite "learning" {
    hasImports = assay.eq (builtins.match ".*imports.*=.*" src != null) true;
  }
