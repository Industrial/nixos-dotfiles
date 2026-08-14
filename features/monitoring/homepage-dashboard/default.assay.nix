# Colocated suite for features/monitoring/homepage-dashboard/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "homepage-dashboard" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
