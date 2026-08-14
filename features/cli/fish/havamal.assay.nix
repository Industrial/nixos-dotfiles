# Colocated suite for features/cli/fish/havamal.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./havamal.nix;
in
  assay.suite "havamal" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
