# Colocated suite for features/programming/vscode/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "vscode" {
    mentionsSystemPackages = assay.eq (builtins.match ".*systemPackages.*" src != null) true;
  }
