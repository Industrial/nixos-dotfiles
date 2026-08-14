# Colocated suite for profiles/crypto.nix
let
  assay = import ./../common/assay/default.nix;
  src = builtins.readFile ./crypto.nix;
in
  assay.suite "crypto" {
    hasImports = assay.eq (builtins.match ".*imports.*=.*" src != null) true;
  }
