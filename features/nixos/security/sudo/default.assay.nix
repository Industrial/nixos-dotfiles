# Colocated suite for features/nixos/security/sudo/default.nix
let
  assay = import ./../../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "sudo" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
