# Colocated suite for hosts/huginn/hardware.nix
let
  assay = import ./../../common/assay/default.nix;
  src = builtins.readFile ./hardware.nix;
in
  assay.suite "huginn-hardware" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 20) true;
  }
