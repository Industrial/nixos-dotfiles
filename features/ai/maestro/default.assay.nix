# Colocated suite for features/ai/maestro/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "maestro" {
    hasSystemPackages = assay.eq (builtins.match ".*systemPackages.*" src != null) true;
    callsPackageNix = assay.eq (builtins.match ".*callPackage ./package.nix.*" src != null) true;
  }
