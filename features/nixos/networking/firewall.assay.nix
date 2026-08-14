# Colocated suite for features/nixos/networking/firewall.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./firewall.nix;
in
  assay.suite "firewall" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
