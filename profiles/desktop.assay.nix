# Colocated suite for profiles/desktop.nix
let
  assay = import ./../common/assay/default.nix;
  src = builtins.readFile ./desktop.nix;
in
  assay.suite "desktop" {
    hasImports = assay.eq (builtins.match ".*imports.*=.*" src != null) true;
  }
