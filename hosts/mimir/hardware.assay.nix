# Colocated suite for hosts/mimir/hardware.nix
let
  assay = import ./../../common/assay/default.nix;
  src = builtins.readFile ./hardware.nix;
in
  assay.suite "mimir-hardware" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 20) true;
  }
