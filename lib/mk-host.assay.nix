let
  assay = import ../common/assay/default.nix;
  src = builtins.readFile ./mk-host.nix;
in
  assay.suite "mk-host" {
    nonEmpty = assay.eq ((builtins.stringLength src) > 20) true;
    hasNixosSystem = assay.eq (builtins.match ".*nixosSystem.*" src != null) true;
  }
