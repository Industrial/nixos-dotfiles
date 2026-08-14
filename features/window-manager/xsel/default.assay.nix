# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {xsel = "xsel";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "xsel" {
    systemPackages = assay.eq mod.environment.systemPackages ["xsel"];
  }
