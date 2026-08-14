# Colocated suite for hosts/mimir/filesystems.nix
let
  assay = import ./../../common/assay/default.nix;
  src = builtins.readFile ./filesystems.nix;
in
  assay.suite "mimir-filesystems" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 20) true;
  }
