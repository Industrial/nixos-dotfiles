# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {television = "television";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "television" {
    systemPackages = assay.eq mod.environment.systemPackages ["television"];
  }
