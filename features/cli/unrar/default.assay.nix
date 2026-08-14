# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {unrar = "unrar";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "unrar" {
    systemPackages = assay.eq mod.environment.systemPackages ["unrar"];
  }
