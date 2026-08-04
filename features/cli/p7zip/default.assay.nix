# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {p7zip = "p7zip";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "p7zip" {
    systemPackages = assay.eq mod.environment.systemPackages ["p7zip"];
  }
