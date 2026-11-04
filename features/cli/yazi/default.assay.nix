# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {yazi = "yazi";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "yazi" {
    systemPackages = assay.eq mod.environment.systemPackages ["yazi"];
  }
