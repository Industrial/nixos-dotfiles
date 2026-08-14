# Colocated suite: systemPackages from stubbed pkgs.
let
  assay = import ./../../../common/assay/default.nix;
  pkgs = {"claude-code" = "claude-code";};
  mod = import ./default.nix {inherit pkgs;};
in
  assay.suite "claude-code" {
    systemPackages = assay.eq mod.environment.systemPackages ["claude-code"];
  }
