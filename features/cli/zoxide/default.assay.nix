# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {zoxide = "zoxide";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "zoxide" {
    systemPackages = assay.eq mod.environment.systemPackages ["zoxide"];
  }
