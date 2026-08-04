# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {nettools = "nettools";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "nettools" {
    systemPackages = assay.eq mod.environment.systemPackages ["nettools"];
  }
