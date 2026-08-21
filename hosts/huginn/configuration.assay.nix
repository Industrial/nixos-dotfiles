let
  assay = import ../../common/assay/default.nix;
  src = builtins.readFile ./configuration.nix;
in
  assay.suite "configuration" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 50) true;
    importsMobileProfile = assay.eq (builtins.match ".*profiles/mobile.nix.*" src != null) true;
  }
