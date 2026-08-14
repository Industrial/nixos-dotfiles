# Colocated suite for features/learning/tolaria/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "tolaria" {
    mentionsSystemPackages = assay.eq (builtins.match ".*systemPackages.*" src != null) true;
  }
