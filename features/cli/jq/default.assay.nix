# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { jq = "jq"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "jq" {
    systemPackages = assay.eq mod.environment.systemPackages [ "jq" ];
  }
