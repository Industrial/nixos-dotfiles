# Colocated suite for devenv.nix
let
  assay = import ./common/assay/default.nix;
  src = builtins.readFile ./devenv.nix;
in
  assay.suite "devenv" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 50) true;
  }
