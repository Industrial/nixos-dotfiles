# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {bisq2 = "bisq2";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "bisq" {
    systemPackages = assay.eq mod.environment.systemPackages ["bisq2"];
  }
