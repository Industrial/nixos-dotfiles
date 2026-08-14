# Colocated suite for hosts/drakkar/filesystems.nix
let
  assay = import ./../../common/assay/default.nix;
  src = builtins.readFile ./filesystems.nix;
in
  assay.suite "drakkar-filesystems" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 20) true;
  }
