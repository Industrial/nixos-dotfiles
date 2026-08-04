# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { ngrok = "ngrok"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "ngrok" {
    systemPackages = assay.eq mod.environment.systemPackages [ "ngrok" ];
  }
