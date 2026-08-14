# Colocated suite for features/creative/openpencil/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "openpencil" {
    mentionsSystemPackages = assay.eq (builtins.match ".*systemPackages.*" src != null) true;
  }
