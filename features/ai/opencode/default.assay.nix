# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {opencode = "opencode";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "opencode" {
    systemPackages = assay.eq mod.environment.systemPackages ["opencode"];
  }
