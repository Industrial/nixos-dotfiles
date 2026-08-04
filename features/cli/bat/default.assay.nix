# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { bat = "bat"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "bat" {
    systemPackages = assay.eq mod.environment.systemPackages [ "bat" ];
  }
