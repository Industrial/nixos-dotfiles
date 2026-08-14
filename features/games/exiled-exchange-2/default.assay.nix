# Colocated suite for features/games/exiled-exchange-2/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "exiled-exchange-2" {
    mentionsSystemPackages = assay.eq (builtins.match ".*systemPackages.*" src != null) true;
  }
