# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {delta = "delta";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "delta" {
    systemPackages = assay.eq mod.environment.systemPackages ["delta"];
  }
