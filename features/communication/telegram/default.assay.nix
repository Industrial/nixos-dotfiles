# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {"telegram-desktop" = "telegram-desktop";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "telegram" {
    systemPackages = assay.eq mod.environment.systemPackages ["telegram-desktop"];
  }
