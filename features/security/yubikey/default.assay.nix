# Colocated suite for features/security/yubikey/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "yubikey" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 0) true;
  }
