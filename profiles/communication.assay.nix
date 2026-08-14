# Colocated suite for profiles/communication.nix
let
  assay = import ./../common/assay/default.nix;
  src = builtins.readFile ./communication.nix;
in
  assay.suite "communication" {
    hasImports = assay.eq (builtins.match ".*imports.*=.*" src != null) true;
  }
