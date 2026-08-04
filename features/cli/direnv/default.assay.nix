# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {direnv = "direnv";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "direnv" {
    systemPackages = assay.eq mod.environment.systemPackages ["direnv"];
  }
