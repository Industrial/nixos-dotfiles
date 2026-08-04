# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {procs = "procs";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "procs" {
    systemPackages = assay.eq mod.environment.systemPackages ["procs"];
  }
