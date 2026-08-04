# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { meld = "meld"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "meld" {
    systemPackages = assay.eq mod.environment.systemPackages [ "meld" ];
  }
