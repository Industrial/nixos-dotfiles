# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {bluetuith = "bluetuith";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "bluetuith" {
    systemPackages = assay.eq mod.environment.systemPackages ["bluetuith"];
  }
