# Colocated suite for features/ai/hermes-agent/package.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./package.nix;
in
  assay.suite "package" {
    hasImports = assay.eq (builtins.match ".*imports.*=.*" src != null) true;
  }
