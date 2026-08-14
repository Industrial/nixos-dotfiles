# Colocated suite for features/monitoring/prometheus/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "prometheus" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
