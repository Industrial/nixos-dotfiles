# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {vlc = "vlc";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "vlc" {
    systemPackages = assay.eq mod.environment.systemPackages ["vlc"];
  }
