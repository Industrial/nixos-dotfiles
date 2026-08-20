# Colocated suite for features/ai/hermes-agent/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "hermes-agent" {
    hasSystemPackages = assay.eq (builtins.match ".*systemPackages.*" src != null) true;
    noBundledMcpImports = assay.eq (builtins.match ".*../lean-ctx.*" src != null) false;
  }
