# Colocated suite for features/ai/context7/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "context7" {
    hasSystemPackages = assay.eq (builtins.match ".*systemPackages.*" src != null) true;
    callsPackageNix = assay.eq (builtins.match ".*callPackage ./package.nix.*" src != null) true;
  }
