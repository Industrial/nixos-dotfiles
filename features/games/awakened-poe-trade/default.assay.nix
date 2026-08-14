# Colocated suite for features/games/awakened-poe-trade/default.nix
let
  assay = import ./../../../common/assay/default.nix;
  src = builtins.readFile ./default.nix;
in
  assay.suite "awakened-poe-trade" {
    mentionsSystemPackages = assay.eq (builtins.match ".*systemPackages.*" src != null) true;
    wrapsAppImage = assay.eq (builtins.match ".*appimageTools.*" src != null) true;
  }
