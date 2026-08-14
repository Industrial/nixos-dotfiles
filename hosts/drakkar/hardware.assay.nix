# Colocated suite for hosts/drakkar/hardware.nix
let
  assay = import ./../../common/assay/default.nix;
  src = builtins.readFile ./hardware.nix;
in
  assay.suite "drakkar-hardware" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 20) true;
  }
