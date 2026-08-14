# Colocated suite for hosts/mimir/flake.nix
let
  assay = import ./../../common/assay/default.nix;
  src = builtins.readFile ./flake.nix;
in
  assay.suite "flake" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 50) true;
  }
