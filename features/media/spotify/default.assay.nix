# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {spotify = "spotify";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "spotify" {
    systemPackages = assay.eq mod.environment.systemPackages ["spotify"];
  }
