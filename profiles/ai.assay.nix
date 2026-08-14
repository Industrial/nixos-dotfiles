# Colocated suite for profiles/ai.nix
let
  assay = import ./../common/assay/default.nix;
  src = builtins.readFile ./ai.nix;
in
  assay.suite "ai" {
    hasImports = assay.eq (builtins.match ".*imports.*=.*" src != null) true;
  }
