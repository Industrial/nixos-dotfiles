# Colocated suite for features/nixos/networking/dns.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./dns.nix;
in
  assay.suite "dns" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
