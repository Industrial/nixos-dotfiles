# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {keepassxc = "keepassxc";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "keepassxc" {
    systemPackages = assay.eq mod.environment.systemPackages ["keepassxc"];
  }
