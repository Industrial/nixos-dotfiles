# Colocated suite for hosts/drakkar/disko.nix
let
  assay = import ./../../common/assay/default.nix;
  src = builtins.readFile ./disko.nix;
in
  assay.suite "drakkar-disko" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 20) true;
  }
