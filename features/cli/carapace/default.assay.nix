# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {carapace = "carapace";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "carapace" {
    systemPackages = assay.eq mod.environment.systemPackages ["carapace"];
  }
