# Colocated suite for hosts/mimir/disko.nix
let
  assay = import ./../../common/assay/default.nix;
  src = builtins.readFile ./disko.nix;
in
  assay.suite "mimir-disko" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 20) true;
  }
