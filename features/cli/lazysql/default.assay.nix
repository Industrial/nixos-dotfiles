# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {lazysql = "lazysql";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "lazysql" {
    systemPackages = assay.eq mod.environment.systemPackages ["lazysql"];
  }
