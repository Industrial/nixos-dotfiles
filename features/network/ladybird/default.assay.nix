# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {ladybird = "ladybird";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "ladybird" {
    systemPackages = assay.eq mod.environment.systemPackages ["ladybird"];
  }
