# Colocated suite for hosts/huginn/filesystems.nix
let
  assay = import ./../../common/assay/default.nix;
  src = builtins.readFile ./filesystems.nix;
in
  assay.suite "huginn-filesystems" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 20) true;
  }
