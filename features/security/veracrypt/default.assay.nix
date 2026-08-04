# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {veracrypt = "veracrypt";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "veracrypt" {
    systemPackages = assay.eq mod.environment.systemPackages ["veracrypt"];
  }
