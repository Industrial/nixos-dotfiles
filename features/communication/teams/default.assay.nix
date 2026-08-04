# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = { "teams-for-linux" = "teams-for-linux"; };
  mod = import ./default.nix { inherit pkgs; };

in
  assay.suite "teams" {
    systemPackages = assay.eq mod.environment.systemPackages [ "teams-for-linux" ];
  }
