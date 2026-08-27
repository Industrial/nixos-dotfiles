# Colocated suite for features/ai/lean-ctx/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "lean-ctx" {
    hasSystemPackages = assay.eq (builtins.match ".*systemPackages.*" src != null) true;
    callsPackageNix = assay.eq (builtins.match ".*callPackage ./package.nix.*" src != null) true;
  }
